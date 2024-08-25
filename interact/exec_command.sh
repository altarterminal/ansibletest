#!/bin/sh
set -u

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -i<inventory file>
Options :

execute command on multiple hosts

-i: specify the inventory file for ansible
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_i=''

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -i*)                 opt_i=${arg#-i}      ;; 
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
  echo "${0##*/}: ansible-playbook comannd cannot be found" 1>&2
  exit 1
fi

if [ ! -f "${opt_i}" ] || [ ! -r "${opt_i}" ]; then
  echo "${0##*/}: <${opt_i}> cannot be accessed for inventory" 1>&2
  exit 1
fi

readonly INVENTORY_FILE=${opt_i}
readonly NOW_DATE=$(date '+%Y%m%d%H%M%S')
readonly TEMPLATE_NAME=${TMP:-/tmp}/${0##*/}_${NOW_DATE}.XXXXXX

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_FILE=$(mktemp "${TEMPLATE_NAME}")
trap "[ -e ${PLAYBOOK_FILE} ] && rm ${PLAYBOOK_FILE}" EXIT

#####################################################################
# function
#####################################################################

exec_command () (
inventory_file=$1
command_string=$2

# check command string
first_word=$(printf '%s\n' "${command_string}" | awk '{print $1}')
# check the runtime privilede
if [ _"${first_word}" = _'sudo' ]; then
  is_become='yes'
  command_string=$(printf '%s\n' "${command_string}" | sed 's#^ *sudo##')
else
  is_become='no'
fi

# make a playbook
cat <<'EOF'                                                         |
- name: execute a command
  hosts: all
  gather_facts: no
  become: <<is_become>>
  tasks:
    - name: execute
      ansible.builtin.shell: |
        <<command_string>>
EOF
sed 's#<<is_become>>#'"${is_become}"'#'                             |
sed 's#<<command_string>>#'"${command_string}"'#'                   |
cat >"${PLAYBOOK_FILE}"

# execute ansible playbook and parse the result
ansible-playbook -v -i "${inventory_file}" "${PLAYBOOK_FILE}"       |
sed -n '/^TASK \[execute\]/,/^$/p'                                  |
sed '1d;$d'                                                         |

sed 's/^.*: \[\(.*\)\] => \(.*\)/{"hostname":"\1","result":"OK","state":\2}/'                      |
sed 's/^fatal: \[\(.*\)\]: \(FAILED\)! => \(.*\)/{"hostname":"\1","result":"\2","state":\3}/'      |
sed 's/^fatal: \[\(.*\)\]: \(UNREACHABLE\)! => \(.*\)/{"hostname":"\1","result":"\2","state":\3}/' |

while read -r line
do
  hostname=$(printf '%s' "${line}" | jq -r '.hostname')
  result=$(printf '%s' "${line}"   | jq -r '.result')

  if    [ "${result}" = 'OK' ]; then
    printf '%s\n' "${line}" | jq '.state.stdout' | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>stdout<T>!'
    printf '%s\n' "${line}" | jq '.state.stderr' | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>stderr<T>!'
    printf '%s\n' "${line}" | jq '.state.rc'     | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>returncode<T>!'
   elif [ "${result}" = 'FAILED' ]; then
    printf '%s\n' "${line}" | jq '.state.stdout' | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>stdout<T>!'
    printf '%s\n' "${line}" | jq '.state.stderr' | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>stderr<T>!'
    printf '%s\n' "${line}" | jq '.state.rc'     | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>returncode<T>!'
  elif  [ "${result}" = 'UNREACHABLE' ]; then
    printf '%s\n' '""'                           | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>stdout<T>!'
    printf '%s\n' "${line}" | jq '.state.msg'    | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>stderr<T>!'
    printf '%s\n' '255'                          | perl -pe 's/\\n/\n/g' | sed 's!^!'"${hostname}"'<M>returncode<T>!'
  fi
done
)

#####################################################################
# main routine
#####################################################################

while true
do
  printf '%s' 'execute command ("q" for quit) > '
  read -r cmd

  case "${cmd}" in
    q) exit 0 ;;
    *) exec_command "${INVENTORY_FILE}" "${cmd}" ;;
  esac
done
