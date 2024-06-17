#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <ledger>
Options : -d<output dir>

make inventory files from <ledger>.
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_d='.'

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -d*)                 opt_d=${arg#-d}      ;;
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

[ ! -e "${opt_d}" ] && mkdir -p "${opt_d}"
if [ ! -d "${opt_d}" ] || [ ! -w "${opt_d}" ]; then
  echo "${0##*/}: <${opt_d}> is an invalid directory" 1>&2
  exit 1
fi

readonly LEDGER_FILE=${opr}
readonly OUTPUT_DIR=${opt_d%/}
readonly SITE_FILE='site.yml'

#####################################################################
# main routine
#####################################################################

# delete the old top playbook
[ -f "${OUTPUT_DIR}/${SITE_FILE}" ] && rm "${OUTPUT_DIR}/${SITE_FILE}"

jq -c '.softlist[]' "${LEDGER_FILE}"                                |
while read -r soft; do
  name=$(echo "${soft}" | jq -r '.name')
  cmd=$(echo "${soft}" | jq -r '.cmd')
  opt=$(echo "${soft}" | jq -r '.opt')
  ver=$(echo "${soft}" | jq -r '.ver')

  # make check playbook
  { 
    echo "- name: ${name}"
    echo "  hosts: hosts_${name}"
    echo "  gather_facts: no"
    echo "  tasks:"
    echo "    - name: check ${name} exists"
    echo "      shell: type ${cmd}"
    echo "    - name: check ${name}'s version"
    echo "      shell: ${cmd} ${opt} | grep -F \"${ver}\""
  } > "${OUTPUT_DIR}/playbook_${name}.yml"

  # make completion playbook
  {
    echo "- name: ${name}_complement"
    echo "  hosts: hosts_${name}_complement"
    echo "  gather_facts: no"
    echo "  tasks:"
    echo "    - name: check ${name} NOT exists"
    echo "      shell: ! type ${cmd}"
  } > "${OUTPUT_DIR}/playbook_${name}_complement.yml"
done
