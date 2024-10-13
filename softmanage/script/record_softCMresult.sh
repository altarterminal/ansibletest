#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -l<softCM ledger> -r<record file> <result>
Options :

update <record file> with info of <softCM ledger> and <result>.
<result> should be the format as below
  <the name of soft>_CM <the result(OK/NG)> <the NG hosts>

-r: specify the <record file> to which the result be added.
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
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -l*)                 opt_l=${arg#-l}      ;;
    -r*)                 opt_r=${arg#-r}      ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
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
  echo "ERROR:${0##*/}: <${opt_l}> cannot be accessed" 1>&2
  exit 1
fi

if [ -e "${opt_r}" ]; then
  if [ ! -f "${opt_r}" ] || [ ! -w "${opt_r}" ]; then
    echo "ERROR:${0##*/}: <${opt_r}> cannot be accessed" 1>&2
    exit 1
  fi
fi

#if [ "_${opr}" = '_' ] || [ "_${opr}" = '_-' ]; then
#  opr=''
#elif [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
#  echo "${0##*/}: <${opr}> cannot be opened" 1>&2
#  exit 1
#fi

readonly LEDGER_FILE=${opt_l}
readonly RECORD_FILE=${opt_r}
readonly RESULT_LINE=${opr}
readonly DATE=$(date '+%Y/%m/%d-%H:%M:%S')

#####################################################################
# main routine
#####################################################################

# decompose the result
name=$(printf '%s' "${RESULT_LINE}"    | awk '{print $1}')
result=$(printf '%s' "${RESULT_LINE}"  | awk '{print $2}')
nghosts=$(printf '%s' "${RESULT_LINE}" | awk '{print $3}')

# check whether there are any results
if [ "${result}" != 'OK' -a "${result}" != 'NG' ]; then
  echo "INFO:${0##*/}: no result has been recorded for <${name}>. no hosts?" 1>&2
  exit 0
fi

# if the record file not exists, make and initialize it
if [ ! -e "${RECORD_FILE}" ]; then
  echo "INFO:${0##*/}: <${RECORD_FILE}> not exist so make it" 1>&2
  mkdir -p "$(dirname ${RECORD_FILE})"
  printf '[]\n' >"${RECORD_FILE}"
fi

# extract the parameter
hosts=$(cat "${LEDGER_FILE}"                                        |
        jq -cr '.[] | select(.name=="'"${name}"'") | .hosts'        )

# construct the update expression
exp=$(printf '. |= .+[{"date":"%s","result":"%s","hosts":%s}]'      \
      "${DATE}" "${result}" "${hosts}"                              )

# make the record file after update
jq "${exp}" "${RECORD_FILE}" >"${RECORD_FILE}.tmp"

# replace the record file
mv "${RECORD_FILE}.tmp" "${RECORD_FILE}"
