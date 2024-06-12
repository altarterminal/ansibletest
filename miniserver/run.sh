#!/bin/sh
set -eu

#####################################################################
# setting
#####################################################################

SCRIPT_DIR='script'
LEDGER_FILE='ledger.json'
PLAYBOOK_DIR='playbook'

#####################################################################
# make files
#####################################################################

${SCRIPT_DIR}/make_book.sh -d${PLAYBOOK_DIR} ${LEDGER_FILE}
${SCRIPT_DIR}/make_inventory.sh ${LEDGER_FILE} > inventory.ini

#####################################################################
# exec playbook
#####################################################################

find ${PLAYBOOK_DIR} -name "*.yml"                                  |

while read -r playbook
do
  ansible-playbook -i inventory.ini ${playbook}                     |
  ${SCRIPT_DIR}/parse_result.sh
done
