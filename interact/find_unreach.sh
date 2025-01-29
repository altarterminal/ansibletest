#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -c

List hosts from <inventory file> which are unreachable.

-c: Enable the output in form of comma-seperated list.
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_c='no'

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -c)                  opt_c='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "$opr" ]; then
        opr="${arg}"
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if ! type ansible >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: ansible comannd not found" 1>&2
  exit 1
fi

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "ERROR:${0##*/}: invalid file specified <${opr}>" 1>&2
  exit 1
fi

readonly INVENTORY_FILE="${opr}"
readonly IS_COMMA="${opt_c}"

#####################################################################
# main routine
#####################################################################

ansible -i "${INVENTORY_FILE}" all -m ping                          |

sed 's#^\([^ ]*\) | SUCCESS => {#{"hostname":"\1","result":"OK",#'  |
sed 's#^\([^ ]*\) | [^ ]* => {#{"hostname":"\1","result":"NG",#'    |

jq -c .                                                             |
while read -r line
do
  hostname=$(echo "${line}" | jq -r '.hostname')
  result=$(echo "${line}"   | jq -r '.result')

  if [ "${result}" = 'NG' ]; then
    echo "${hostname}"
  fi
done                                                                |

if [ "${IS_COMMA}" = 'yes' ]; then
  tr '\n' ','                                                       |
  sed 's/,$//'                                                      |
  grep ^
else
  cat
fi
