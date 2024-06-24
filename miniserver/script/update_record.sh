#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -l<host ledger> -r<record file> <result>
Options : -r

update <record> with info of <host ledger> and <result>
-r specify the file to record result
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_l=''
opt_r=''

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

if [ -e "${opt_r}" ]; then
  if [ ! -f "${opt_r}" ] || [ ! -w "${opt_r}" ]; then
    echo "${0##*/}: <${opt_r}> cannot be accessed" 1>&2
    exit 1
  fi
fi

if [ "_${opr}" = '_' ] || [ "_${opr}" = '_-' ]; then
  opr=''
elif [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "${0##*/}: <${opr}> cannot be opened" 1>&2
  exit 1
fi

readonly LEDGER_FILE=${opt_l}
readonly RECORD_FILE="${opt_r}"
readonly RESULT_FILE=${opr}
readonly DATE=$(date '+%Y/%m/%d')

#####################################################################
# main routine
#####################################################################

# if the record file not exists, make and initialize it
if [ ! -e "${RECORD_FILE}" ]; then
  echo "${0##*/}: <${RECORD_FILE}> not exist so make it" 1>&2
  mkdir -p "$(dirname ${RECORD_FILE})"
  printf '[]\n' > "${RECORD_FILE}"
fi

# input the result
read -r name result nghosts < ${RESULT_FILE:-'/dev/stdin'}  

# if invalid result is included, output warning
if [ _"${name}" != _'Update' ]; then
  printf '%s: the result (%s, %s, %s) is invalid for <Update>\n'    \
    "${0##*/}" "${name}" "${result}" "${nghosts}"                   \
    1>&2
fi

hosts=$(jq '.[].name' "${LEDGER_FILE}" | jq '.' -sc)

# construct the update expression
exp='. |= .+[{"date":"%s","result":"%s","hosts":%s}]'
exp=$(printf "${exp}" "${DATE}" "${result}" "${hosts}")

# make the record file after update
jq "${exp}" "${RECORD_FILE}" > "${RECORD_FILE}.tmp"

# replace the record file
mv "${RECORD_FILE}.tmp" "${RECORD_FILE}"
