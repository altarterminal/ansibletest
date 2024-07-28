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
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -s*)                 opt_s=${arg#-s}      ;;
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

if [ ! -f "${opt_s}" ] || [ ! -r "${opt_s}" ]; then
  echo "${0##*/}: <${opt_s}> cannot be accessed" 1>&2
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
readonly SOFTC_LEDGER="${ANSIBLE_DIR}/softc_ledger.json"
readonly SOFT_PLAYBOOK_DIR="${ANSIBLE_DIR}/soft_playbook"
readonly SOFTC_PLAYBOOK_DIR="${ANSIBLE_DIR}/softc_playbook"
readonly UPDATE_PLAYBOOK_DIR="${ANSIBLE_DIR}/update_playbook"

readonly UPDATE_PLAYBOOK="${UPDATE_PLAYBOOK_DIR}/playbook_update.yml"

readonly SOFT_RECORD_DIR="${ANSIBLE_DIR}/soft_record"
readonly SOFTC_RECORD_DIR="${ANSIBLE_DIR}/softc_record"
readonly UPDATE_RECORD_DIR="${ANSIBLE_DIR}/update_record"

readonly UPDATE_RECORD_FILE="${UPDATE_RECORD_DIR}/Update_record.json"

#####################################################################
# make files
#####################################################################

mkdir -p "${SOFT_PLAYBOOK_DIR}"
mkdir -p "${SOFT_RECORD_DIR}"
mkdir -p "${SOFTC_PLAYBOOK_DIR}"
mkdir -p "${SOFTC_RECORD_DIR}"
mkdir -p "${UPDATE_PLAYBOOK_DIR}"
mkdir -p "${UPDATE_RECORD_DIR}"

echo "start: make pre-required files"
${SCRIPT_DIR}/inventory.sh -s"${SOFT_LEDGER}" "${HOST_LEDGER}" >"${INVENTORY}"
${SCRIPT_DIR}/softc_ledger.sh -s"${SOFT_LEDGER}" "${HOST_LEDGER}" >"${SOFTC_LEDGER}"
echo "end: make pre-required files"
echo ""

echo "start: make playbooks"
${SCRIPT_DIR}/soft_playbook.sh  -d${SOFT_PLAYBOOK_DIR}  ${SOFT_LEDGER}
${SCRIPT_DIR}/softc_playbook.sh -d${SOFTC_PLAYBOOK_DIR} ${SOFTC_LEDGER}
${SCRIPT_DIR}/update_playbook.sh >"${UPDATE_PLAYBOOK}"
echo "end: make playbooks"
echo ""

#####################################################################
# exec playbook
#####################################################################

# execute: check software version
echo "start: check software version"
find "${SOFT_PLAYBOOK_DIR}" -name "playbook_*.yml"                  |
sort                                                                |
while read -r playbook
do
  name=$(basename "${playbook}" .yml | sed 's/^playbook_//')
  record_file="${SOFT_RECORD_DIR}/${name}_record.yml"
  result=$(${SCRIPT_DIR}/exec_playbook.sh \
    -i"${INVENTORY}" "${playbook}")
  ${SCRIPT_DIR}/soft_record.sh  \
    -l"${SOFT_LEDGER}" -r"${record_file}" "${result}"
done
echo "end: check software version"
echo ""

# execute: check software NOT installed
echo "start: check software NOT installed"
find "${SOFTC_PLAYBOOK_DIR}" -name "playbook_*.yml"                 |
sort                                                                |
while read -r playbook
do
  name=$(basename "${playbook}" .yml | sed 's/^playbook_//')
  record_file="${SOFTC_RECORD_DIR}/${name}_record.yml"
  result=$(${SCRIPT_DIR}/exec_playbook.sh \
    -i"${INVENTORY}" "${playbook}")

  ${SCRIPT_DIR}/softc_record.sh \
    -l"${SOFTC_LEDGER}" -r"${record_file}" "${result}"
done
echo "end: check software NOT installed"
echo ""

# execute: apt upgrade
echo "start: apt upgrade"
result=$(${SCRIPT_DIR}/exec_playbook.sh \
  -i"${INVENTORY}" "${UPDATE_PLAYBOOK}")
${SCRIPT_DIR}/update_record.sh \
  -l"${HOST_LEDGER}" -r"${UPDATE_RECORD_FILE}" "${result}"
echo "end: apt upgrade"
