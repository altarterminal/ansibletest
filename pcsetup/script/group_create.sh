#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options : -g<group name> -i<group id> -j<group ledger> -d

Create groups on <inventory file>.

-g: Specify the group name (default: <$(id -ng)> = the effective group name of this user). 
-i: Specify the group id (default: <$(id -g)> = the effective group id of this user).
-j: Specify the json on which the an array of group name and group id are defined. This is prioritized to -u and -i options.
-d: Enable dry run (default: no).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_g="$(id -ng)"
opt_i="$(id -g)"
opt_j=''
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -g*)                 opt_g=${arg#-g}      ;;
    -i*)                 opt_i=${arg#-i}      ;;
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

  readonly INVENTORY_FILE="${opr}"
fi

if [ -n "${opt_j}" ]; then
  if [ ! -f "${opt_j}" ] || [ ! -r "${opt_j}" ]; then
    echo "ERROR:${0##*/}: invalid file specified" 1>&2
    exit 1
  fi

  readonly IS_JSON='yes'
  readonly JSON_FILE="${opt_j}"
else
  readonly IS_JSON='no'
  readonly GROUP_NAME="${opt_g}"
  readonly GROUP_ID="${opt_i}"
fi

readonly LEDGER_FILE="${opr}"
readonly DATE="$(date '+%Y%m%d_%H%M%S')"

readonly TEMP_IF_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_if_XXXXXX"
readonly TEMP_BODY_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_body_XXXXXX"
readonly TEMP_JSON_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_json_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_IF_FILE="$(mktemp "${TEMP_IF_NAME}")"
readonly PLAYBOOK_BODY_FILE="$(mktemp "${TEMP_BODY_NAME}")"
readonly JSON_MIDDLE_FILE="$(mktemp "${TEMP_JSON_NAME}")"

trap "
  [ -e ${PLAYBOOK_IF_FILE} ]   && rm ${PLAYBOOK_IF_FILE}
  [ -e ${PLAYBOOK_BODY_FILE} ] && rm ${PLAYBOOK_BODY_FILE}
  [ -e ${JSON_MIDDLE_FILE} ]   && rm ${JSON_MIDDLE_FILE}
" EXIT

if [ "${IS_JSON}" = 'yes' ]; then
  cat "${JSON_FILE}" >"${JSON_MIDDLE_FILE}"
else
  printf '[{"name":"%s","id":"%s"}]\n'                              \
    "${GROUP_NAME}" "${GROUP_ID}"                                   |
  cat >"${JSON_MIDDLE_FILE}"
fi

#####################################################################
# check
#####################################################################

jq -cr '.[]' "${JSON_MIDDLE_FILE}"                                  |
while read -r line;
do
  name=$(echo "${line}" | jq -r '.name // empty')
  id=$(echo "${line}" | jq -r '.id // empty')

  if [ -z "${name}" ]; then
    echo "ERROR:${0##*/}: user name must be specified" 1>&2
    echo 'error'
  fi

  if ! echo "${id}" | grep -Eq '^[0-9]+$'; then
    echo "ERROR:${0##*/}: invalid gid specified <${id}>" 1>&2
    echo 'error'
  fi
done                                                                |
awk ' END { if(NR != 0) { exit 1; } } '

#####################################################################
# main routine
#####################################################################

{
  cat <<'EOF'                                                       |
- name: create group
  hosts: all
  gather_facts: no
  become: yes
  tasks:
  - name: create group if
    include_tasks: <<playbook_body_file>>
    with_items:
EOF
  sed 's!<<playbook_body_file>>!'"${PLAYBOOK_BODY_FILE}"'!'

  jq -c '.[]' "${JSON_MIDDLE_FILE}"                                 |
  while read -r line;
  do
    group_name=$(echo "${line}" | jq -r '.name')
    group_id=$(echo "${line}" | jq -r '.id')

    printf '      - { "group_name":"%s", "group_id":"%s" }\n'       \
      "${group_name}" "${group_id}"
  done
} >"${PLAYBOOK_IF_FILE}"

cat <<'EOF'                                                         |
- name: create group body
  ansible.builtin.group:
    name: "{{ item.group_name }}"
    gid: "{{ item.group_id }}"
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
