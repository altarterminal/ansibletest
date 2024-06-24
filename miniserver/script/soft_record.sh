#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -l<ledger> <result>
Options : -r

update <record> with info of <ledger> and <result>
-r specify the direcotry in which record files are included
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_l=''
opt_r='.'

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -l*)                 opt_l=${arg#-l}      ;;
    -r*)                 opt_r=${arg#-r}      ;;
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

if [ ! -f "${opt_l}" ] || [ ! -r "${opt_l}" ]; then
  echo "${0##*/}: <${opt_l}> cannot be accessed" 1>&2
  exit 1
fi

if [ ! -d "${opt_r}" ] || [ ! -w "${opt_r}" ]; then
  echo "${0##*/}: <${opt_r}> cannot be accessed" 1>&2
  exit 1
fi

if [ "_${opr}" = '_' ] || [ "_${opr}" = '_-' ]; then
  opr=''
elif [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "${0##*/}: <${opr}> cannot be opened" 1>&2
  exit 1
fi

readonly LEDGER_FILE=${opt_l}
readonly RECORD_DIR=${opt_r}
readonly RESULT_FILE=${opr}
readonly DATE=$(date '+%Y/%m/%d')

#####################################################################
# main routine
#####################################################################

cat ${RESULT_FILE:+"${RESULT_FILE}"}                                |
sort                                                                |

while read -r name result nghosts
do
  RECORD_FILE="${RECORD_DIR}/${name}_record.yml"

  # if the record file not exists, make and initialize it
  if [ ! -e "${RECORD_FILE}" ]; then
    echo "${0##*/}: <${RECORD_FILE}> not exist so make it" 1>&2
    mkdir -p "$(dirname ${RECORD_FILE})"
    printf '[]\n' > "${RECORD_FILE}"
  fi
 
  ver=$(cat "${LEDGER_FILE}"                                        |
        jq -r '.[] | select(.name=="'"${name}"'") | .ver'           )
  hosts=$(cat "${LEDGER_FILE}"                                      |
        jq -cr '.[] | select(.name=="'"${name}"'") | .hosts'        )

  # construct the update expression
  exp='. |= .+[{"date":"%s","result":"%s","ver":"%s","hosts":%s}]'
  exp=$(printf "${exp}" "${DATE}" "${result}" "${ver}" "${hosts}")

  # make the record file after update
  jq "${exp}" "${RECORD_FILE}" > "${RECORD_FILE}.tmp"

  # replace the record file
  mv "${RECORD_FILE}.tmp" "${RECORD_FILE}"
done
