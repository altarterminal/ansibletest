#!/bin/sh
set -eu

#####################################################################
# setting 
#####################################################################

THIS_DIR=$(dirname $0)
TOP_DIR="${THIS_DIR}/../.."
TEST_DIR="${THIS_DIR}/.."
SCRIPT_DIR="${TOP_DIR}/script"
PLAYBOOK_DIR="${TEST_DIR}/pplaybook"

LEDGER_FILE="${TEST_DIR}/ledger.json"
INVENTORY_FILE="${TEST_DIR}/inventory.ini"
PLAYBOOK_FILE="${PLAYBOOK_DIR}/prepare_situation.yml"

${SCRIPT_DIR}/make_inventory.sh ${LEDGER_FILE} > "${INVENTORY_FILE}"
cp "${TOP_DIR}/ansible.cfg" "${TEST_DIR}"

if ! docker ps | grep -q 'container-ansible-test0'; then
  echo "${0##*/}: some container not running" 1>&2
  exit 1
fi

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

ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"
