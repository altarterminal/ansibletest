#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -j<host ledger> -d

Setup hosts file.

-j: Specify the json file on which hostname and its ip address are for setup (default: ./host_ledger.json).
-d: Enable dry-run (default: disabled).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_j='./host_ledger.json'
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
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

readonly IS_DRYRUN="${opt_d}"

if [ "${IS_DRYRUN}" = 'no' ]; then
  if ! type ansible-playbook >/dev/null 2>&1; then
    echo "ERROR:${0##*/}: ansible command not found" 1>&2
    exit 1
  fi

  if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
    echo "ERROR:${0##*/}: invalid inventory specified <${opr}>" 1>&2
    exit 1
  fi

  readonly INVENTORY="${opr}"
fi

if [ ! -f "${opt_j}" ] || [ ! -r "${opt_j}" ]; then
  echo "ERROR:${0##*/}: invalid host ledger specified <${opt_j}>" 1>&2
  exit 1
fi

readonly HOST_LEDGER_FILE="${opt_j}"

readonly TEMP_NAME="${TMPDIR:-/tmp}/${0##*/}_$(date '+%Y%m%d_%H%M%S')_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_FILE=$(mktemp "${TEMP_NAME}")
trap "
  [ -e ${PLAYBOOK_FILE} ] && rm ${PLAYBOOK_FILE}
" EXIT

#####################################################################
# main routine
#####################################################################

{
  cat <<'EOF'
- name: setup hosts
  hosts: all
  gather_facts: no
  become: yes

  tasks:
  - name: setup hosts
    ansible.builtin.blockinfile:
      path: /etc/hosts
      block: |
EOF

  jq -c '.[]' "${HOST_LEDGER_FILE}" |
  while read -r host; do
    host_name=$(echo "${host}" | jq -r '.name')
    host_ip=$(echo "${host}"   | jq -r '.ip')

    printf '        %s\t%s\n' "${host_ip}" "${host_name}"
  done
} >"${PLAYBOOK_FILE}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK_FILE}"
else
   ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"
fi
