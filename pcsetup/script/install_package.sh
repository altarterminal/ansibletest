#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -p<package list> -j<package ledger> -d

Create accouts on <accout ledger> to hosts on <inventory>.
If there has already been the account, nothing is done.

-p: Specify the package comma-seperated list (default: 'openssh-client').
-d: enable dry run (default: disabled).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_p='openssh-client'
opt_j=''
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -p*)                 opt_p=${arg#-p}      ;;
    -j*)                 opt_j=${arg#-j}      ;;
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

  if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
    echo "ERROR:${0##*/}: invalid inventory specified <${opr}>" 1>&2
    exit 1
  fi

  readonly INVENTORY_FILE="${opr}"
fi

if [ -n "${opt_j}" ]; then
  if [ ! -f "${opt_j}" ] || [ ! -r "${opt_j}" ]; then
    echo "ERROR:${0##*/}: invalid file specified <${opt_j}>" 1>&2
    exit 1
  fi

  readonly IS_JSON='yes'
  readonly INPUT_JSON_FILE="${opt_j}"
else
  readonly IS_JSON='no'
  readonly PACKAGE_LIST="${opt_p}"
fi

readonly DATE="$(date '+%Y%m%d_%H%M%S')"

readonly TEMP_PLAYBOOK_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_playbook_XXXXXX"
readonly TEMP_JSON_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_json_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_FILE="$(mktemp "${TEMP_PLAYBOOK_NAME}")"
readonly JSON_FILE="$(mktemp "${TEMP_JSON_NAME}")"

trap "
  [ -e ${PLAYBOOK_FILE} ] && rm ${PLAYBOOK_FILE}
  [ -e ${JSON_FILE} ] && rm ${JSON_FILE}
" EXIT

if [ "${IS_JSON}" = 'yes' ]; then
  cat "${INPUT_JSON_FILE}" >"${JSON_FILE}"
else
  echo "${PACKAGE_LIST}"                                            |
  tr ',' '\n'                                                       |
  sed 's!=! !'                                                      |
  while read -r name ver
  do
    printf '{"name":"%s","ver":"%s"},\n' "${name}" "${ver}"
  done                                                              |
  sed '$s!,$!!'                                                     |
  { echo "["; cat; echo "]"; }                                      |
  cat >"${JSON_FILE}"
fi

#####################################################################
# main routine
#####################################################################

{
  cat <<'  EOF'
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

  jq -c '.[]' "${JSON_FILE}"                                        |
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
  ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"
fi
