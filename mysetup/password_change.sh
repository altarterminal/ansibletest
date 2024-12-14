#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -u<user name> -d

Change the password.

-u: specify the user name (default: $(whoami) = the user name who executes this)
-i: specify the id for uid and gid if the user is newly created (default: $(id -u) = the uid of who executes this)
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

if ! printf '%s\n' "${opt_i}" | grep -Eq '^[0-9]+$'; then
  echo "${0##*/}: invalid id specified <${opt_i}>" 1>&2
  exit 1
fi

readonly USER_NAME=${opt_u}
readonly TEMP_NAME=${TMPDIR:-/tmp}/${0##*/}_$(date '+%Y%m%d_%H%M%S')_XXXXXX

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK=$(mktemp "${TEMP_NAME}")
trap "[ -e ${PLAYBOOK} ] && rm ${PLAYBOOK}; stty echo" EXIT

if [ "${IS_DRYRUN}" = 'yes' ]; then
  readonly PASSWORD='this-is-password'
else
  stty -echo
  while true; do
    printf 'new password > '; read -r first_pass; echo ""
    if [ -z "${first_pass}" ]; then
      echo "${0##*/}: empty password not permitted" 1>&2
      continue
    fi

    printf 'retype > '; read -r second_pass; echo "";
    if [ "${first_pass}" != "${second_pass}" ]; then
      echo "${0##*/}: password not matched" 1>&2
      continue
    fi

    break
  done
  stty echo

  readonly PASSWORD=${first_pass}
fi

#####################################################################
# main routine
#####################################################################

cat <<'EOF'                                                         |
- name: change password
  hosts: all
  gather_facts: no
  become: yes
  vars:
    user_name: "<<user_name>>"
    password: "<<password>>"
  tasks:
    - name: check the user exist
      ansible.builtin.shell: |
        id "{{ user_name }}"

    - name: change the password
      ansible.builtin.user:
        name: "{{ user_name }}"
        password: "{{ password | password_hash('sha512') }}"
EOF

sed 's#<<user_name>>#'"${USER_NAME}"'#'                             |
sed 's#<<password>>#'"${PASSWORD}"'#'                               |
cat >"${PLAYBOOK}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK}"
else
  ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}"
fi
