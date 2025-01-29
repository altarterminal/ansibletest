#!/bin/sh
set -u

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file> <command>
Options : -u<user name>

Execute <command> on hosts on <inventory file>.

-u: Specify the user name to execute command (default: <$(whoami)> = who executes this).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr_i=''
opr_c=''
opt_u="$(whoami)"

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
    *)
      if [ $i -eq $(($# - 1)) ] && [ -z "${opr_i}" ]; then
        opr_i="${arg}"
      elif [ $i -eq $# ] && [ -z "${opr_c}" ]; then
        opr_c="${arg}"
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if ! type ansible-playbook >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: ansible command not found" 1>&2
  exit 1
fi

if ! type jq >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: jq command not found" 1>&2
  exit 1
fi

if [ ! -f "${opr_i}" ] || [ ! -r "${opr_i}" ]; then
  echo "ERROR:${0##*/}: invalid inventory specified <${opr_i}>" 1>&2
  exit 1
fi

if [ -z "${opr_c}" ]; then
  echo "ERROR:${0##*/}: command must be specified" 1>&2
  exit 1
fi

readonly INVENTORY_FILE="${opr_i}"
readonly COMMAND_STRING="${opr_c}"
readonly USER_NAME="${opt_u}"

readonly NOW_DATE=$(date '+%Y%m%d%H%M%S')
readonly TEMPLATE_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_FILE="$(mktemp "${TEMPLATE_NAME}")"
trap "[ -e ${PLAYBOOK_FILE} ] && rm ${PLAYBOOK_FILE}" EXIT

#####################################################################
# main routine
#####################################################################

# check command string
first_word=$(printf '%s\n' "${COMMAND_STRING}" | awk '{print $1}')

# check the runtime privilede
if [ "${first_word}" = 'sudo' ]; then
  is_become='yes'
  become_name='root'
  command_body=$(printf '%s\n' "${COMMAND_STRING}" | sed 's#^ *sudo##')
else
  is_become='yes'
  become_name="${USER_NAME}"
  command_body=${COMMAND_STRING}
fi

# make a playbook
cat <<'EOF'                                                         |
- name: execute a command
  hosts: all
  gather_facts: no
  become: <<is_become>>
  become_user: <<become_name>>
  tasks:
    - name: execute
      ansible.builtin.shell: |
        <<command_body>>
EOF
sed 's#<<is_become>>#'"${is_become}"'#'                             |
sed 's#<<become_name>>#'"${become_name}"'#'                         |
sed 's#<<command_body>>#'"${command_body}"'#'                       |
cat >"${PLAYBOOK_FILE}"

# execute ansible playbook and parse the result
ansible-playbook -v -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"       |
sed -n '/^TASK \[execute\]/,/^$/p'                                  |
sed '1d;$d'                                                         |

sed 's/^.*: \[\(.*\)\] => \(.*\)/{"hostname":"\1","result":"OK","state":\2}/'                 |
sed 's/^fatal: \[\(.*\)\]: \([A-Z]*\)! => \(.*\)/{"hostname":"\1","result":"\2","state":\3}/' |

# sort by hostname
jq -s .                                                             |
jq '. | sort_by(.hostname)'                                         |
jq -c '.[]'                                                         |

while read -r line
do
  hostname=$(printf '%s' "${line}" | jq -r '.hostname')
  result=$(printf '%s' "${line}"   | jq -r '.result')

  if   [ "${result}" = 'OK' ] || [ "${result}" = 'FAILED' ] ; then
    stdout_line="$(printf '%s\n' "${line}" | jq -r '.state.stdout')"
    stderr_line="$(printf '%s\n' "${line}" | jq -r '.state.stderr')"
    rtcode_line="$(printf '%s\n' "${line}" | jq -r '.state.rc')"
  elif [ "${result}" = 'UNREACHABLE' ]; then
    stdout_line=''
    stderr_line="$(printf '%s\n' "${line}" | jq -r '.state.msg')"
    rtcode_line='255'
  else
    echo "ERROR:${0##*/}: unexpected pattern <${result}> (but continues process)" 1>&2
  fi

  {
    printf "${stdout_line:-\n}" | grep ^ | sed 's!^!stdout<T>!'
    printf "${stderr_line:-\n}" | grep ^ | sed 's!^!stderr<T>!'
    printf "${rtcode_line:-\n}" | grep ^ | sed 's!^!rtcode<T>!'
  }                                                                 |
  sed 's!^!'"${hostname}"'<M>!'
done
