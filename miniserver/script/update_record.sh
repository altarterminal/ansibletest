#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -l<ledger> -r<record> <result>
Options :

update <record> with info of <ledger> and <result>
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

if [ ! -f "${opt_r}" ] || [ ! -r "${opt_r}" ]; then
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
readonly RECORD_FILE=${opt_r}
readonly RESULT_FILE=${opr}
readonly DATE=$(date '+%Y/%m/%d')

#####################################################################
# main routine
#####################################################################

cat ${RESULT_FILE:+"${RESULT_FILE}"}                                |

while read -r name result_binary nghosts
do
  # select the result
  if [ _"${result_binary}" = _"NG" ]; then
    result="NG:${nghosts}"
  else
    result="OK"
  fi
  
  # the method to retrieve info is different between update and version monitor
  if [ _"${name}" = _'Update' ]; then
    ver='latest'
    hosts=$(jq '.hostlist[].name' "${LEDGER_FILE}" | jq '.' -sc)
  else
    ver=$(jq -r '.softlist[] | select(.name=="'"${name}"'") | .ver' "${LEDGER_FILE}")
    hosts=$(jq -cr '.softlist[] | select(.name=="'"${name}"'") | .hosts' "${LEDGER_FILE}")
  fi

  # make a piece of update script
  printf 'jq '"'"'.recordlist |= map((select(.name=="%s").record |= '     \
    "${name}"
  printf '.+[{"date":"%s","result":"%s","ver":"%s","hosts":%s}]))'"'"' |' \
    "${DATE}" "${result}" "${ver}" "${hosts}"
  echo ""
done                                                                |

# make the whole update script
{
  echo 'cat "${RECORD_FILE}" |'
  cat
  echo 'cat'
}                                                                   |

# exec update
eval "$(cat)"
