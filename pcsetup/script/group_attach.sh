#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -u<user name> -g<group list> -aj<account ledger> -tj<type ledger> -d

Attach groups to accounts on <inventory file>.

-u:  Specify the user name (default: <$(whoami)> = the user name who executes this).
-g:  Specify the group list (default: <$(id -nG | tr ' ' ',')> = the groups to which this user belongs to).
-aj: Specify the json on which an array of user name and its type are defined. This is prioritized to -u and -g options.
-tj: Specify the json on which an array of type name and its group are defined. This is prioritized to -u and -g options.
-d:  Enable dry run (default: no).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_u="$(whoami)"
opt_g="$(id -nG | tr ' ' ',')"
opt_aj=''
opt_tj=''
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
    -g*)                 opt_g=${arg#-g}      ;;
    -aj*)                opt_aj=${arg#-aj}    ;;
    -tj*)                opt_tj=${arg#-tj}    ;;
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

if [ "${IS_DRYRUN}" ]; then
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

if [ -n "${opt_aj}" ] || [ -n "${opt_tj}" ]; then
  if [ ! -f "${opt_aj}" ] || [ ! -r "${opt_aj}" ]; then
    echo "ERROR:${0##*/}: invalid file spedified <${opt_aj}>" 1>&2
    exit 1
  fi

  if [ ! -f "${opt_tj}" ] || [ ! -r "${opt_tj}" ]; then
    echo "ERROR:${0##*/}: invalid file spedified <${opt_tj}>" 1>&2
    exit 1
  fi

  readonly IS_JSON='yes'
  readonly JSON_ACCOUNT_FILE="${opt_aj}"
  readonly JSON_TYPE_FILE="${opt_tj}"
else
  readonly IS_JSON='no'
  readonly USER_NAME="${opt_u}"
  readonly GROUP_NAMES="${opt_g}"
fi

readonly DATE="$(date '+%Y%m%d_%H%M%S')"

readonly TEMP_IF_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_if_XXXXXX"
readonly TEMP_BODY_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_body_XXXXXX"
readonly TEMP_JSON_ACCOUNT_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_json_account_XXXXXX"
readonly TEMP_JSON_TYPE_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_json_type_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_IF_FILE="$(mktemp "${TEMP_IF_NAME}")"
readonly PLAYBOOK_BODY_FILE="$(mktemp "${TEMP_BODY_NAME}")"
readonly JSON_ACCOUNT_MIDDLE_FILE="$(mktemp "${TEMP_JSON_ACCOUNT_NAME}")"
readonly JSON_TYPE_MIDDLE_FILE="$(mktemp "${TEMP_JSON_TYPE_NAME}")"

trap "
  [ -e ${PLAYBOOK_IF_FILE} ] && rm ${PLAYBOOK_IF_FILE}
  [ -e ${PLAYBOOK_BODY_FILE} ] && rm ${PLAYBOOK_BODY_FILE}
  [ -e ${JSON_ACCOUNT_MIDDLE_FILE} ] && rm ${JSON_ACCOUNT_MIDDLE_FILE}
  [ -e ${JSON_TYPE_MIDDLE_FILE} ] && rm ${JSON_TYPE_MIDDLE_FILE}
" EXIT

if [ "${IS_JSON}" = 'yes' ]; then
  cat "${JSON_ACCOUNT_FILE}" >"${JSON_ACCOUNT_MIDDLE_FILE}"
  cat "${JSON_TYPE_FILE}" >"${JSON_TYPE_MIDDLE_FILE}"
else
  GROUP_NAMES_ESC=$(echo "${GROUP_NAMES}" |
    sed 's!^!"!' | sed 's!$!"!' | sed 's!,!","!g')

  printf '[{"name":"%s","type":"%s"}]\n'                            \
    "${USER_NAME}" 'tmptype'                                        |
  cat >"${JSON_ACCOUNT_MIDDLE_FILE}"

  printf '[{"name":"%s","group":[%s]}]\n'                           \
    'tmptype' "${GROUP_NAMES_ESC}"                                  |
  cat >"${JSON_TYPE_MIDDLE_FILE}"
fi

#####################################################################
# main routine
#####################################################################

{
  cat <<'  EOF'                                                     |
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

  jq -r '.[].group' "${JSON_TYPE_MIDDLE_FILE}"                      |
  while read -r line; do echo "${line}" | jq -r '.[]'; done         |
  sort                                                              |
  uniq                                                              |
  xargs -I@ echo "      - @"

  cat <<'  EOF'                                                     |
  - name: attach group if
    include_tasks: <<playbook_body_file>>
    with_items:
  EOF
  sed 's!<<playbook_body_file>>!'"${PLAYBOOK_BODY_FILE}"'!'

  jq -c '.[]' "${JSON_ACCOUNT_MIDDLE_FILE}"                         |
  while read -r line;
  do
    user_name=$(echo "${line}" | jq -r '.name')
    user_type=$(echo "${line}" | jq -r '.type')

    group_list=$(cat "${JSON_TYPE_MIDDLE_FILE}"                     |
      jq '.[] | select(.name=="'"${user_type}"'")'                  |
      jq -r '.group[]'                                              |
      tr '\n' ','                                                   |
      grep ^                                                        |
      sed 's/,$//'                                                  )

    printf '      - { "user_name":"%s", "group_list":"%s" }\n'      \
      "${user_name}" "${group_list}"
  done
} >"${PLAYBOOK_IF_FILE}"

{
  cat <<'  EOF'                                                     |
- name: attach group
  ansible.builtin.user:
    name: "{{ item.user_name }}"
    groups: "{{ item.group_list }}"
    append: yes
  EOF
  cat
} >"${PLAYBOOK_BODY_FILE}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  echo '=== IF ====================================================='
  cat "${PLAYBOOK_IF_FILE}"
  echo ''
  echo '=== BODY ==================================================='
  cat "${PLAYBOOK_BODY_FILE}"
else
  ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_IF_FILE}"
fi
