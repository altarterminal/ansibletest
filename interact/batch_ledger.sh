#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <host ledger>
Options : -k<key> -l<value list> -e

Edit the content of <host ledger>.

-k: Specify the key on which the target specified (default: "no").
-l: Specify the comma-seperated list of the value (default: "").
-e: Enable the target host (default: disable the host).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_k='no'
opt_l=''
opt_e='no'

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -k*)                 opt_k="${arg#-k}"    ;;
    -l*)                 opt_l="${arg#-l}"    ;;
    -e)                  opt_e='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr="${arg}"
      else
        echo "${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "ERROR:${0##*/}: invalid file specified <${opr}>" 1>&2
  exit 1
fi

if ! jq . "${opr}" >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: some grammer error <${opr}>" 1>&2
  exit 1
fi

readonly LEDGER_FILE="${opr}"
readonly KEY="${opt_k}"
readonly VALUE_LIST="${opt_l}"
readonly IS_ENABLE="${opt_e}"

readonly NOW_DATE="$(date '+%Y%m%d%H%M%S')"
readonly TEMPLATE_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_XXXXXX"

#####################################################################
# prepare
#####################################################################

if [ "${IS_ENABLE}" = 'yes' ]; then
  STATE='true'
else
  STATE='false'
fi

QUERY_TEMPLATE="jq '. | if .${KEY} == \"%s\" then .validity = ${STATE} else . end' | "

readonly TEMPLATE_FILE="$(mktemp "${TEMPLATE_NAME}")"
trap "[ -e ${TEMPLATE_FILE} ] && rm ${TEMPLATE_FILE}" EXIT

cat "${LEDGER_FILE}" >"${TEMPLATE_FILE}"

#####################################################################
# main routine
#####################################################################

query=$(\
  echo "${VALUE_LIST}"                                              |
  tr ',' '\n'                                                       |
  xargs printf "${QUERY_TEMPLATE}"                                  |
  { printf "jq '.[]' | "; cat; printf "jq -s '.'"; }                )
  
cat "${TEMPLATE_FILE}"                                              |
eval "${query}"                                                     |
cat >"${LEDGER_FILE}"
