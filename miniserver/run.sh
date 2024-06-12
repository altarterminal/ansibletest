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
${SCRIPT_DIR}/make_inventory.sh  ${LEDGER_FILE} > inventory.ini
