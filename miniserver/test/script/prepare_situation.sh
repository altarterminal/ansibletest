#!/bin/sh
set -eu

#####################################################################
# setting 
#####################################################################

TOP_DIR='..'
SCRIPT_DIR="${TOP_DIR}/script"
LEDGER_FILE='./ledger.json'
PLAYBOOK_DIR='./pplaybook'

${SCRIPT_DIR}/make_inventory.sh ${LEDGER_FILE} > 'inventory.ini'
cp "${TOP_DIR}/ansible.cfg" '.'

if ! docker ps | grep -q 'container-ansible-test1'; then
  echo "${0##*/}: some container not running" 1>&2
  exit 1
fi

if ! docker ps | grep -q 'container-ansible-test2'; then
  echo "${0##*/}: some container not running" 1>&2
  exit 1
fi

if ! type ansible >/dev/null 2>&1; then
  echo "${0##*/}: ansible command not found" 1>&2
  exit 1
fi

#####################################################################
# main routine
#####################################################################

ansible-playbook -i 'inventory.ini' "${PLAYBOOK}/prepare_situation.yml"
