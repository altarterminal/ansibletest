#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <host ledger>
Options :

Edit the content of <host ledger>.
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr="${arg}"
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "ERROR:${0##*/}: invalid inventory specified <${opr}>" 1>&2
  exit 1
fi

if ! type jq >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: jq command not found" 1>&2
  exit 1
fi

readonly INVENTORY_JSON_FILE="${opr}"

readonly NOW_DATE="$(date '+%Y%m%d%H%M%S')"
readonly TEMPLATE_PREV_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_prev_XXXXXX"
readonly TEMPLATE_NEXT_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_next_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly JSON_PREV_FILE="$(mktemp "${TEMPLATE_PREV_NAME}")"
readonly JSON_NEXT_FILE="$(mktemp "${TEMPLATE_NEXT_NAME}")"

trap "
  [ -e ${JSON_PREV_FILE} ] && rm ${JSON_PREV_FILE}
  [ -e ${JSON_NEXT_FILE} ] && rm ${JSON_NEXT_FILE}
" EXIT

cat "${INVENTORY_JSON_FILE}" >"${JSON_PREV_FILE}"

cat "${JSON_PREV_FILE}"                                             |
eval $(\
  jq -c '.[]' "${JSON_PREV_FILE}"                                   |
  awk '{print NR-1}'                                                |
  while read -r num
  do
    printf 'jq ".[%d] += {"no":"%d"}" | ' "${num}" "${num}"
  done                                                              |
  { cat; echo 'cat';})                                              |
cat >"${JSON_NEXT_FILE}"

#####################################################################
# utility
#####################################################################

print_inventory() (
  printf '%s %s %s %s %s\n' 'No' 'name' 'ip' 'port' 'validity'

  jq -c '.[]' "${JSON_NEXT_FILE}"                                   |
  while read -r line
  do
    no=$(echo "${line}"       | jq -r '.no')
    name=$(echo "${line}"     | jq -r '.name')
    ip=$(echo "${line}"       | jq -r '.ip')
    port=$(echo "${line}"     | jq -r '.port')
    validity=$(echo "${line}" | jq -r '.validity')

    printf '%s %s %s %s %s\n' "${no}" "${name}" "${ip}" "${port}" "${validity}"
  done
)

change_host() (
  STATE="$1"
  TARGET_NO="$2"

  if [ "${STATE}" != 'enable' ] && [ "${STATE}" != 'disable' ]; then
    echo "ERROR:${0##*/}: invalid state specified <${STATE}>" 1>&2
    return
  fi

  if ! echo "${TARGET_NO}" | grep -Eq '^([0-9]+,)*[0-9]+$'; then
    echo "ERROR:${0##*/}: invalid input specified <${TARGET_NO}>" 1>&2
    return
  fi

  if [ "${STATE}" = 'enable' ]; then
    str="jq '. | if .no == %d then .validity = true  else . end' | "
  else
    str="jq '. | if .no == %d then .validity = false else . end' | "
  fi

  cat "${JSON_NEXT_FILE}" >"${JSON_PREV_FILE}"

  jq -c '.[]' "${JSON_PREV_FILE}"                                   |
  eval $(echo "${TARGET_NO}"                                        |
    tr ',' '\n'                                                     |
    xargs -L1 printf "${str}"                                       |
    { cat; echo 'jq -s .'; })                                       |
  cat >"${JSON_NEXT_FILE}"
)

store_inventory() {
  cat "${JSON_NEXT_FILE}"                                           |
  jq '.[] | del(.no)'                                               |
  jq . -s                                                           |
  cat >"${INVENTORY_JSON_FILE}"
}

#####################################################################
#
#####################################################################

while true
do
  print_inventory

  printf 'edit ([e]nable / [d]isable / [q]uit) > '
  read -r cmd

  case "${cmd}" in
    e*) change_host 'enable'  "${cmd#e}" ;;
    d*) change_host 'disable' "${cmd#d}" ;;
    q)  store_inventory; exit ;;
    *) ;;
  esac
done
