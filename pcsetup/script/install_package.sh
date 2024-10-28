#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -i<inventory> <package ledger>
Options : -d

Create accouts on <accout ledger> to hosts on <inventory>.
If there has already been the account, nothing is done.

-d: enable dry run (default: no)
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_i=''
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -i*)                 opt_i=${arg#-i}      ;;
    -d)                  opt_d='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr=${arg}
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

readonly IS_DRYRUN=${opt_d}

if [ "${IS_DRYRUN}" = 'no' ]; then
  if ! type ansible-playbook >/dev/null 2>&1; then
    echo "ERROR:${0##*/}: ansible command not found" 1>&2
    exit 1
  fi

  if [ ! -f "${opt_i}" ] || [ ! -r "${opt_i}" ]; then
    echo "ERROR:${0##*/}: invalid inventory specified <${opt_i}>" 1>&2
    exit 1
  fi

  readonly INVENTORY_FILE=${opt_i}
fi

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "ERROR:${0##*/}: invalid ledger specified <${opr}>" 1>&2
  exit 1
fi

readonly LEDGER_FILE=${opr}
readonly DATE=$(date '+%Y%m%d_%H%M%S')

readonly TEMP_NAME=${TMPDIR:-/tmp}/${0##*/}_${DATE}_XXXXXX

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_FILE=$(mktemp "${TEMP_NAME}.yml")
trap "
  [ -e ${PLAYBOOK_FILE} ] && rm ${PLAYBOOK_FILE}
" EXIT

#####################################################################
# main routine
#####################################################################

{
  cat <<'EOF'
- name: install apt package
  hosts: all
  gather_facts: no
  become: yes
  tasks:
  - name: install apt package
    ansible.builtin.apt:
      update_cache: yes
      name:
EOF

  jq -c '.[]' "${LEDGER_FILE}"                                      |
  while read -r line;
  do
    package_name=$(echo "${line}" | jq -r '.name')
    package_ver=$(echo "${line}" | jq -r '.ver // empty')

    if [ -z "${package_ver}" ]; then
      printf '        - %s\n' "${package_name}"
    else
      printf '        - %s=%s\n' "${package_name}" "${package_ver}"
    fi
  done
} >"${PLAYBOOK_FILE}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK_FILE}"
else
  ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_IF_FILE}"
fi
