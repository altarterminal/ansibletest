#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
cat <<-USAGE 1>&2
Usage   : ${0##*/} <host ledger>
Options :

Execute command on multiple hosts on <host ledger>
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

if ! type ansible-playbook >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: ansible command not found" 1>&2
  exit 1
fi

if ! type jq >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: jq command not found" 1>&2
  exit 1
fi

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "ERROR:${0##*/}: invalid file speicified <${opr}>" 1>&2
  exit 1
fi

# original ledger is not modified
readonly ORG_LEDGER_FILE="${opr}"

readonly TOP_DIR="$(dirname "$0")"

readonly NOW_DATE="$(date '+%Y%m%d%H%M%S')"
readonly LEDGER_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_ledger_XXXXXX"
readonly INVENTORY_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_inventory_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly LEDGER_FILE="$(mktemp "${LEDGER_NAME}")"
readonly INVENTORY_FILE="$(mktemp "${INVENTORY_NAME}")"
trap "
  [ -e ${LEDGER_FILE} ]    && rm ${LEDGER_FILE};
  [ -e ${INVENTORY_FILE} ] && rm ${INVENTORY_FILE};
" EXIT

cat "${ORG_LEDGER_FILE}"                                            |
jq '.[] | . += {"validity":true}'                                   |
jq -s .                                                             |
cat >"${LEDGER_FILE}"

#####################################################################
# unitility
#####################################################################

print_menu () {
cat <<'EOF'
h: print this menu
p: print host information
r: invalidate unreachable host
e: edit host validity
c: execute shell command
q: quit
EOF
}

#####################################################################
# main routine
#####################################################################

while true
do
  printf 'menu ("h" for help) > '
  read -r cmd

  case "${cmd}" in
    h) print_menu ;;
    p)
      jq . "${LEDGER_FILE}"
      ;;
    r)
      "${TOP_DIR}/make_inventory.sh" "${LEDGER_FILE}" >"${INVENTORY_FILE}"
      unreachs=$("${TOP_DIR}/find_unreach.sh" "${INVENTORY_FILE}" | tr '\n' ',')
      "${TOP_DIR}/batch_ledger.sh" -k'name' -l"${unreachs}" "${LEDGER_FILE}"
      ;;
    e)
      "${TOP_DIR}/edit_ledger.sh" "${LEDGER_FILE}"
      ;;
    c)
      "${TOP_DIR}/make_inventory.sh" "${LEDGER_FILE}" >"${INVENTORY_FILE}"
      "${TOP_DIR}/exec_command_if.sh" "${INVENTORY_FILE}"
      ;;
    q)
      exit
      ;;
    *)
      ;;
  esac
done
