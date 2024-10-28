#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -i<inventory> -t<type ledger> <accout ledger>
Options : -d

Attach accouts on <accout ledger> to groups on <type ledger> on <inventory>.
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
opt_t=''
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -i*)                 opt_i=${arg#-i}      ;;
    -t*)                 opt_t=${arg#-t}      ;;
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

if [ "${IS_DRYRUN}" ]; then
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

if [ ! -f "${opt_t}" ] || [ ! -r "${opt_t}" ]; then
  echo "ERROR:${0##*/}: invalid ledger specified <${opt_t}>" 1>&2
  exit 1
fi

readonly ACCOUNT_LEDGER_FILE=${opr}
readonly TYPE_LEDGER_FILE=${opt_t}
readonly DATE=$(date '+%Y%m%d_%H%M%S')

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
- name: attach group
  hosts: all
  gather_facts: no
  become: yes
  tasks:
  - name: check the group exists
    ansible.builtin.shell: |
      cat /etc/group | awk -F: '{print $1}' | grep '^{{ item }}$'
    with_items:
EOF
  cat

  cat "${TYPE_LEDGER_FILE}"                                         |
  jq -r '.[].group.[]'                                              |
  sort                                                              |
  uniq                                                              |
  xargs -I@ echo "      - @"

cat <<'EOF'                                                         |
  - name: attach group if
    include_tasks: <<playbook_body_file>>
    with_items:
EOF
  sed 's!<<playbook_body_file>>!'"${PLAYBOOK_BODY_FILE}"'!'

  jq -c '.[]' "${ACCOUNT_LEDGER_FILE}"                              |
  while read -r line;
  do
    user_name=$(echo "${line}" | jq -r '.name')
    user_type=$(echo "${line}" | jq -r '.type')

    group_list=$(cat "${TYPE_LEDGER_FILE}"                          |
      jq '.[] | select(.name=="'"${user_type}"'")'                  |
      jq -r '.group[]'                                              |
      tr '\n' ','                                                   |
      grep ^                                                        |
      sed 's/,$//'                                                  )

    printf '      - { "user_name":"%s", "group_list":"%s" }\n'      \
      "${user_name}" "${group_list}"
  done
} >"${PLAYBOOK_IF_FILE}"

cat <<'EOF'                                                         |
- name: attach group
  ansible.builtin.user:
    name: "{{ item.user_name }}"
    groups: "{{ item.group_list }}"
    append: yes
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
