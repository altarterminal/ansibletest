#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <softc ledger>
Options : -d<output dir>

make ansible playbook files from <softc ledger>.
-d: specify the <output dir> into which output files
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

readonly SOFT_LEDGER=${opr}
readonly OUTPUT_DIR=${opt_d%/}

#####################################################################
# main routine
#####################################################################

jq -c '.[]' "${SOFT_LEDGER}"                                        |
while read -r soft; do
  name=$(echo "${soft}" | jq -r '.name')
  cmd=$(echo "${soft}" | jq -r '.cmd')
  opt=$(echo "${soft}" | jq -r '.opt')
  ver=$(echo "${soft}" | jq -r '.ver')

  # make completion playbook
  {
    echo "- name: ${name}"
    echo "  hosts: hosts_${name}"
    echo "  gather_facts: no"
    echo "  tasks:"
    echo "    - name: check ${name} NOT exists"
    echo "      shell: '! type ${cmd}'"
  } > "${OUTPUT_DIR}/playbook_${name}.yml"
done
