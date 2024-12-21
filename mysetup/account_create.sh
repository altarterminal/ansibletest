#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -u<user name> -i<user id> -d

Create account.

-u: specify the user name (default: <$(whoami)> = the user name who executes this)
-i: specify the user id for uid and gid (default: <$(id -u)> = the id who executes this)
-d: enable dry-run (= only output the playbook and not execute it) (default: disabled)
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_u=$(whoami)
opt_i=$(id -u)
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
    -i*)                 opt_i=${arg#-i}      ;;
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

if [ -z "${opt_u}" ]; then
  echo "ERROR:${0##*/}: user name must be specified" 1>&2
  exit 1
fi

if ! echo "${opt_i}" | grep -Eq '^[0-9]+$' ; then
  echo "ERROR:${0##*/}:  invalid id specified <${opt_i}>" 1>&2
  exit 1
fi

readonly USER_NAME=${opt_u}
readonly USER_ID=${opt_i}
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
- name: create account
  hosts: all
  gather_facts: no
  become: yes
  vars:
    user_name: "<<user_name>>"
    user_id: "<<user_id>>"
  tasks:
    - name: check the user NOT exist
      ansible.builtin.shell: |
        id "{{ user_name }}"
      register: result
      failed_when: result.rc not in [0, 1]

    - name: create account
      ansible.builtin.user:
        name: "{{ user_name }}"
        password: "{{ user_name | password_hash('sha512') }}"
        shell: "/bin/bash"
        uid: "{{ user_id }}"
      when: result.rc == 1
EOF

sed 's#<<user_name>>#'"${USER_NAME}"'#'                             |
sed 's#<<user_id>>#'"${USER_ID}"'#'                                 |
cat >"${PLAYBOOK}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK}"
else
  ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"
fi
