#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -i<inventory> <accout ledger>
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
readonly DATE=$(date '+%Y%m%d_%H%M%S')_

readonly TEMP_IF_NAME=${TMPDIR:-/tmp}/${0##*/}_${DATE}_if_XXXXXX
readonly TEMP_BODY_NAME=${TMPDIR:-/tmp}/${0##*/}_${DATE}_body_XXXXXX

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_IF_FILE=$(mktemp "${TEMP_IF_NAME}")
readonly PLAYBOOK_BODY_FILE=$(mktemp "${TEMP_BODY_NAME}")
trap "
  [ -e ${PLAYBOOK_IF_FILE} ] && rm ${PLAYBOOK_IF_FILE}
  [ -e ${PLAYBOOK_BODY_FILE} ] && rm ${PLAYBOOK_BODY_FILE}
" EXIT

#####################################################################
# main routine
#####################################################################

{
  cat <<'EOF'                                                       |
- name: create account
  hosts: all
  gather_facts: no
  become: yes
  tasks:
  - name: create account if
    include_tasks: <<playbook_body_file>>
    with_items:
EOF
  sed 's!<<playbook_body_file>>!'"${PLAYBOOK_BODY_FILE}"'!'

  jq -c '.[]' "${LEDGER_FILE}"                                      |
  while read -r line;
  do
    user_name=$(echo "${line}" | jq -r '.name')
    user_id=$(echo "${line}" | jq -r '.uid')

    printf '      - { "user_name":"%s", "user_id":"%s" }\n'         \
      "${user_name}" "${user_id}"
  done
} >"${PLAYBOOK_IF_FILE}"

cat <<'EOF'                                                         |
- name: check the account exist
  ansible.builtin.shell: |
    id "{{ item.user_name }}"
  register: result
  failed_when: result.rc not in [0, 1]

- name: create account
  ansible.builtin.user:
    name: "{{ item.user_name }}"
    uid: "{{ item.user_id }}"
    password: "{{ item.user_name | password_hash('sha512') }}"
    shell: "/bin/bash"
  when: result.rc == 1
EOF
cat >"${PLAYBOOK_BODY_FILE}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  echo '=== IF ====================================================='
  cat "${PLAYBOOK_IF_FILE}"
  echo ''
  echo '=== BODY ==================================================='
  cat "${PLAYBOOK_BODY_FILE}"
else
  ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_IF_FILE}"
fi
