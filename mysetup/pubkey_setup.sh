#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -u<user name> -k<key path> -d

Setup public key login.

-u: specify the user name (default: $(whoami) = the user name who executes this)
-k: specify the key path (default: ${HOME}/.ssh/id_rsa)
-d: enable dry-run (= only output the playbook and not execute it) (default: disabled)
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_u=$(whoami)
opt_k=${HOME}/.ssh/id_rsa
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
    -k*)                 opt_k=${arg#-k}      ;;
    -d)                  opt_d='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr=${arg}
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

readonly IS_DRYRUN=${opt_d}

if [ "${IS_DRYRUN}" = 'no' ]; then
  if ! type ansible-playbook >/dev/null 2>&1; then
    echo "ERROR:${0##*/}: ansible command not found" 1>&2
    exit 1
  fi

  if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
    echo "ERROR:${0##*/}: invalid inventory specified <${opr}>" 1>&2
    exit 1
  fi

  readonly INVENTORY=${opr}
fi

if [ ! -f "${opt_k%.pub}" ]     || [ ! -r "${opt_k%.pub}" ] ||
   [ ! -f "${opt_k%.pub}.pub" ] || [ ! -r "${opt_k%.pub}.pub" ]; then
  echo "ERROR:${0##*/}: invalid key specified <${opt_k}>" 1>&2
  exit 1
fi

if [ -z "${opt_u}" ]; then
  echo "ERROR:${0##*/}: user name must be specified" 1>&2
  exit 1
fi

readonly USER_NAME=${opt_u}
readonly KEY_PATH=${opt_k%.pub}
readonly TEMP_NAME=${TMPDIR:-/tmp}/${0##*/}_$(date '+%Y%m%d_%H%M%S')_XXXXXX

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
  tasks:
    - name: check the user exist
      ansible.builtin.shell: |
        id "{{ user_name }}"

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
cat >"${PLAYBOOK}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK}"
else
  ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"
fi
