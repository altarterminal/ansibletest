#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -k<key path> -u<user name> -p<password> -d

setup public key login

-k: specify the key path (default: ${HOME}/.ssh/id_rsa)
-u: specify the user name (default: the user who executes this)
-p: specify the password if the user is newly created (default: <user name>)
-d: specify whether only output the playbook (default: no)
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_k=${HOME}/.ssh/id_rsa
opt_u=$(whoami)
opt_p=$(whoami)
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -k*)                 opt_k=${arg#-k}      ;;
    -u*)                 opt_u=${arg#-u}      ;;
    -p*)                 opt_p=${arg#-p}      ;;
    -d)                  opt_d='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "$opr" ]; then
        opr=$arg
      else
        echo "${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if ! type ansible-playbook >/dev/null 2>&1; then
  echo "${0##*/}: ansible command not found" 1>&2
  exit 1
fi

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "${0##*/}: invalid inventory <${opr}> specified" 1>&2
  exit 1
fi

if [ ! -f "${opt_k%.pub}" ]     || [ ! -r "${opt_k%.pub}" ] ||
   [ ! -f "${opt_k%.pub}.pub" ] || [ ! -r "${opt_k%.pub}.pub" ]; then
  echo "${0##*/}: invalid key <${opt_k}> specified" 1>&2
  exit 1
fi

if [ -z "${opt_u}" ]; then
  echo "${0##*/}: user name must be specified" 1>&2
  exit 1
fi

if [ -z "${opt_p}" ]; then
  echo "${0##*/}: password must be specified" 1>&2
  exit 1
fi

readonly INVENTORY=${opr}
readonly KEY_PATH=${opt_k%.pub}
readonly USER_NAME=${opt_u}
readonly PASSWORD=${opt_p}
readonly IS_DRYRUN=${opt_d}
readonly TEMP_NAME=${TMP:-/tmp}/${0##*/}_$(date '+%Y%m%d_%H%M%S')_XXXXXX

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK=$(mktemp "${TEMP_NAME}")
trap "[ -e ${PLAYBOOK} ] && rm ${PLAYBOOK}" EXIT

#####################################################################
# main routine
#####################################################################

cat <<'EOF'                                                         |
- name: setup public key login
  hosts: all
  gather_facts: no
  become: yes
  vars:
    user_name: "<<user_name>>"
    public_key: "<<key_path>>.pub"
    secret_key: "<<key_path>>"
    password: "<<password>>"
  tasks:
    - name: check the user exist
      ansible.builtin.shell: |
        id "{{ user_name }}"
      register: result
      failed_when: result.rc not in [0, 1]

    - name: create user
      ansible.builtin.user:
        name: "{{ user_name }}"
        password: "{{ password | password_hash('sha512') }}"
        shell: "/bin/bash"
      when: result.rc == 1

    - name: create ssh directory
      ansible.builtin.file:
        path: "/home/{{ user_name }}/.ssh"
        state: "directory"
        owner: "{{ user_name }}"
        group: "{{ user_name }}"
        mode: "755"

    - name: copy secret key
      ansible.builtin.copy:
        remote_src: false
        src: "{{ secret_key }}"
        dest: "/home/{{ user_name }}/.ssh/{{ secret_key | basename }}"
        owner: "{{ user_name }}"
        group: "{{ user_name }}"
        mode: "600"

    - name: setup authorized_keys
      ansible.posix.authorized_key:
        user: "{{ user_name }}"
        key: "{{ lookup('file', public_key) }}"
EOF

sed 's#<<user_name>>#'"${USER_NAME}"'#'                             |
sed 's#<<key_path>>#'"${KEY_PATH}"'#'                               |
sed 's#<<password>>#'"${PASSWORD}"'#'                               |
cat >"${PLAYBOOK}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK}"
else
  ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"
fi
