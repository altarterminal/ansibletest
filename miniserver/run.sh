#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <ledger>
Options :

run maintenance process from <ledger>.
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
        opr=$arg
      else
        echo "${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "${0##*/}: <${opr}> cannot be accessed" 1>&2
  exit 1
fi

readonly LEDGER_FILE=${opr}
readonly SCRIPT_DIR='script'
readonly TEMPLATE_DIR='template'
readonly PLAYBOOK_DIR='playbook'

#####################################################################
# make files
#####################################################################

${SCRIPT_DIR}/make_book.sh -d${PLAYBOOK_DIR} ${LEDGER_FILE}
${SCRIPT_DIR}/make_inventory.sh ${LEDGER_FILE} > 'inventory.ini'

cp "${TEMPLATE_DIR}/update_template.yml" "${PLAYBOOK_DIR}/playbook__update.yml"

#####################################################################
# exec playbook
#####################################################################

find ${PLAYBOOK_DIR} -name "*.yml"                                  |
sort                                                                |
while read -r playbook
do
  ansible-playbook -i inventory.ini ${playbook}                     |
  ${SCRIPT_DIR}/parse_result.sh
done
