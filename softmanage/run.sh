#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -s<soft ledger> <host ledger>
Options :

run maintenance process from <soft ledger> and <host ledger>.
USAGE
  exit 1
}

#####################################################################
# parse arg
#####################################################################

opr=''
opt_s=''

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -s*)                 opt_s=${arg#-s}      ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr=$arg
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "ERROR:${0##*/}: <${opr}> cannot be accessed" 1>&2
  exit 1
fi

if [ ! -f "${opt_s}" ] || [ ! -r "${opt_s}" ]; then
  echo "ERROR:${0##*/}: <${opt_s}> cannot be accessed" 1>&2
  exit 1
fi

#####################################################################
# set paramters
#####################################################################

readonly HOST_LEDGER=${opr}
readonly SOFT_LEDGER=${opt_s}

readonly THIS_DIR=$(dirname $0)
readonly ANSIBLE_DIR="${THIS_DIR}/ansible"
readonly SCRIPT_DIR="${THIS_DIR}/script"

readonly INVENTORY="${ANSIBLE_DIR}/inventory.ini"
readonly SOFTCM_LEDGER="${ANSIBLE_DIR}/softcm_ledger.json"

readonly SOFT_PLAYBOOK_DIR="${ANSIBLE_DIR}/soft_playbook"
readonly SOFTCM_PLAYBOOK_DIR="${ANSIBLE_DIR}/softcm_playbook"
readonly UPDATE_PLAYBOOK_DIR="${ANSIBLE_DIR}/update_playbook"

readonly SOFT_RECORD_DIR="${ANSIBLE_DIR}/soft_record"
readonly SOFTCM_RECORD_DIR="${ANSIBLE_DIR}/softcm_record"
readonly UPDATE_RECORD_DIR="${ANSIBLE_DIR}/update_record"

readonly UPDATE_PLAYBOOK_FILE="${UPDATE_PLAYBOOK_DIR}/playbook_update.yml"
readonly UPDATE_RECORD_FILE="${UPDATE_RECORD_DIR}/record_update.json"

readonly DEBUG_DIR="${ANSIBLE_DIR}/debug"

#####################################################################
# make files
#####################################################################

mkdir -p "${SOFT_PLAYBOOK_DIR}"
mkdir -p "${SOFT_RECORD_DIR}"
mkdir -p "${SOFTCM_PLAYBOOK_DIR}"
mkdir -p "${SOFTCM_RECORD_DIR}"
mkdir -p "${UPDATE_PLAYBOOK_DIR}"
mkdir -p "${UPDATE_RECORD_DIR}"
mkdir -p "${DEBUG_DIR}"

echo "start: make pre-required files"
${SCRIPT_DIR}/make_inventory.sh -s"${SOFT_LEDGER}" "${HOST_LEDGER}" >"${INVENTORY}"
${SCRIPT_DIR}/make_softCMledger.sh -s"${SOFT_LEDGER}" "${HOST_LEDGER}" >"${SOFTCM_LEDGER}"
echo "end: make pre-required files"

echo "start: make playbooks"
${SCRIPT_DIR}/make_softplaybook.sh  -d"${SOFT_PLAYBOOK_DIR}"  "${SOFT_LEDGER}"
${SCRIPT_DIR}/make_softCMplaybook.sh -d"${SOFTCM_PLAYBOOK_DIR}" "${SOFTCM_LEDGER}"
${SCRIPT_DIR}/make_updateplaybook.sh -d"${UPDATE_PLAYBOOK_DIR}"
echo "end: make playbooks"

#####################################################################
# exec playbook
#####################################################################

# execute: check software version ###################################
echo "start: check software version"
jq -cr '.[].name' "${SOFT_LEDGER}"                                  |
sort                                                                |
while read -r name
do
  playbook_file="${SOFT_PLAYBOOK_DIR}/playbook_${name}.yml"
  record_file="${SOFT_RECORD_DIR}/record_${name}.yml"

  echo "start: check ${name}"
  result=$(${SCRIPT_DIR}/exec_playbook.sh -i"${INVENTORY}" -d"${DEBUG_DIR}" "${playbook}")
  ${SCRIPT_DIR}/record_softresult.sh -s"${SOFT_LEDGER}" -r"${record_file}" "${result}"
  echo "end: check ${name}"
done
echo "end: check software version"

# execute: check software NOT installed #############################
echo "start: check software NOT installed"
jq -cr '.[].name' "${SOFTCM_LEDGER}"                                |
sort                                                                |
while read -r name
do
  playbook_file="${SOFTCM_PLAYBOOK_DIR}/playbook_${name}.yml"
  record_file="${SOFTCM_RECORD_DIR}/record_${name}.yml"

  echo "start: check ${name}"
  result=$(${SCRIPT_DIR}/exec_playbook.sh -i"${INVENTORY}" -d"${DEBUG_DIR}" "${playbook}")
  ${SCRIPT_DIR}/record_softCMresult.sh -s"${SOFTCM_LEDGER}" -r"${record_file}" "${result}"
  echo "end: check ${name}"
done
echo "end: check software NOT installed"

# execute: apt upgrade ##############################################
echo "start: apt upgrade"
result=$(${SCRIPT_DIR}/exec_playbook.sh -i"${INVENTORY}" -d"${DEBUG_DIR}" "${UPDATE_PLAYBOOK_FILE}")
${SCRIPT_DIR}/record_updateresult.sh -l"${HOST_LEDGER}" -r"${UPDATE_RECORD_FILE}" "${result}"
echo "end: apt upgrade"
