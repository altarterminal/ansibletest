#!/bin/sh
set -eux

#####################################################################
# setting 
#####################################################################

THIS_DIR=$(dirname $0)
TOP_DIR="${THIS_DIR}/../.."
TEST_DIR="${THIS_DIR}/.."
SCRIPT_DIR="${TOP_DIR}/script"
PLAYBOOK_DIR="${TEST_DIR}/pplaybook"

SOFT_LEDGER_FILE="${TEST_DIR}/ledgertest/soft_ledger.json"
HOST_LEDGER_FILE="${TEST_DIR}/ledgertest/host_ledger.json"
INVENTORY_FILE="${TEST_DIR}/inventory.ini"
PLAYBOOK_FILE="${PLAYBOOK_DIR}/prepare_situation.yml"

#####################################################################
# prepare
#####################################################################

git clone 'https://github.com/altarterminal/ledgertest.git'

${SCRIPT_DIR}/inventory.sh                                          \
  -s"${SOFT_LEDGER_FILE}" "${HOST_LEDGER_FILE}"                     \
  > "${INVENTORY_FILE}"

cp "${TOP_DIR}/ansible.cfg" "${TEST_DIR}"

#####################################################################
# check the condition
#####################################################################

if ! docker ps | grep -q 'gen-ubuntu-no-1'; then
  echo "${0##*/}: some container not running" 1>&2
  exit 1
fi

if ! docker ps | grep -q 'gen-ubuntu-no-2'; then
  echo "${0##*/}: some container not running" 1>&2
  exit 1
fi

if ! docker ps | grep -q 'gen-ubuntu-no-3'; then
  echo "${0##*/}: some container not running" 1>&2
  exit 1
fi

if ! type ansible-playbook >/dev/null 2>&1; then
  echo "${0##*/}: ansible command not found" 1>&2
  exit 1
fi

#####################################################################
# main routine
#####################################################################

ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"
