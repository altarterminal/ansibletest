#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -b

remove hosts from <inventory file> which are unreachable.

-b: specify whether the backup of old inventory will be created (default: no)
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_b='no'

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -b)                  opt_b='yes'          ;;
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

if ! type ansible >/dev/null 2>&1; then
  echo "${0##*/}: ansible-playbook comannd cannot be found" 1>&2
  exit 1
fi

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "${0##*/}: <${opr}> cannot be accessed" 1>&2
  exit 1
fi

if ! printf '%s\n' "${opr}" | grep -q '\.ini$'; then
  echo "${0##*/}: <${opr}> may not be inventory" 1>&2
  exit 1
fi

readonly INVENTORY_FILE=${opr}
readonly IS_BACKUP=${opt_b}

readonly NOW_DATE=$(date '+%Y%m%d%H%M%S')
readonly TEMPLATE_NAME=${TMP:-/tmp}/${0##*/}_${NOW_DATE}.XXXXXX

#####################################################################
# prepare
#####################################################################

readonly DST_INVENTORY_FILE=${INVENTORY_FILE}
readonly SRC_INVENTORY_FILE=$(mktemp "${TEMPLATE_NAME}")
trap "[ -e ${SRC_INVENTORY_FILE} ] && rm ${SRC_INVENTORY_FILE}" EXIT

cp "${INVENTORY_FILE}" "${SRC_INVENTORY_FILE}"

if [ "${IS_BACKUP}" = 'yes' ]; then
  BACKUP_INVENTORY_FILE=${INVENTORY_FILE%.ini}_${NOW_DATE}.ini
  cp "${INVENTORY_FILE}" "${BACKUP_INVENTORY_FILE}"
fi

#####################################################################
# main routine
#####################################################################

ansible -i "${SRC_INVENTORY_FILE}" all -m ping                      |

sed 's#^\([^ ]*\) | SUCCESS => {#{"hostname":"\1","result":"OK",#'  |
sed 's#^\([^ ]*\) | [^ ]* => {#{"hostname":"\1","result":"NG",#'    |

jq -c .                                                             |
while read -r line
do
  hostname=$(echo "${line}" | jq -r '.hostname')
  result=$(echo "${line}"   | jq -r '.result')

  if [ "${result}" = 'NG' ]; then
    echo "${hostname}"
    echo "${0##*/}: removed <${hostname}>" 1>&2
  fi
done                                                                |

xargs -I{} printf '%s\n' "grep -v '^{} ' | "                        |
{ cat; echo 'cat'; }                                                |
tr '\n' ' '                                                         |

eval 'cat '"${SRC_INVENTORY_FILE}"' | '"$(cat)"                     |
cat >"${DST_INVENTORY_FILE}"

