#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <target file> <inventory file>
Options : -u<user name> -c<update cotent> -f<update file> -m<suffix marker> -d

Update the <target file path>.

-u: Specify the user name to manipulate (default: <$(whoami)> = the user name who executes this).
-c: Specify the file content to overwrite (default: "").
-f: Specify the file path which includes the content to overwrite (This is prior to -c option if something is specified).
-m: Specify the suffix marker for ANSIBLE MANAGED BLOCK (default: none).
-d: Enable dry-run (default: disabled).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr_f=''
opr_i=''
opt_u=$(whoami)
opt_c=''
opt_f=''
opt_m=''
opt_d='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -f*)                 opt_f=${arg#-f}      ;;
    -m*)                 opt_m=${arg#-m}      ;;
    -d)                  opt_d='yes'          ;;
    *)
      if [ $i -eq $(($# - 1)) ] && [ -z "${opr_f}" ]; then
        opr_f=${arg}
      elif [ $i -eq $# ] && [ -z "${opr_i}" ]; then
        opr_i=${arg}
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

  if [ ! -f "${opr_i}" ] || [ ! -r "${opr_i}" ]; then
    echo "ERROR:${0##*/}: invalid inventory specified <${opr_i}>" 1>&2
    exit 1
  fi

  readonly INVENTORY_FILE="${opr_i}"
fi

if [ -z "${opt_u}" ]; then
  echo "ERROR:${0##*/}: user name must be specified <${opt_u}>" 1>&2
  exit 1
fi

if [ -n "${opt_f}" ]; then
  if [ ! -f "${opt_f}" ] || [ ! -r "${opt_f}" ]; then
    echo "ERROR:${0##*/}: invalid file specified <${opt_f}>" 1>&2
    exit 1
  fi

  readonly IS_FILE='yes'
  readonly INPUT_CONTENT_FILE="${opt_f}"
else
  readonly IS_FILE='no'
  readonly INPUT_CONTENT="${opt_c}"
fi

readonly TARGET_FILE="${opr_f}"
readonly USER_NAME="${opt_u}"
readonly SUFFIX_MARKER="${opt_m}"

readonly DATE="$(date '+%Y%m%d_%H%M%S')"

readonly TEMP_PLAYBOOK_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_playbook_XXXXXX"
readonly TEMP_CONTENT_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_content_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_FILE=$(mktemp "${TEMP_PLAYBOOK_NAME}")
readonly CONTENT_FILE=$(mktemp "${TEMP_CONTENT_NAME}")

trap "
  [ -e ${PLAYBOOK_FILE} ] && rm ${PLAYBOOK_FILE}
  [ -e ${CONTENT_FILE} ] && rm ${CONTENT_FILE}
" EXIT

if [ "${IS_FILE}" = 'yes' ]; then
  cat "${INPUT_CONTENT_FILE}" >"${CONTENT_FILE}"
else
  printf "${INPUT_CONTENT}"'\n' >"${CONTENT_FILE}"
fi

#####################################################################
# main routine
#####################################################################

cat <<'EOF'                                                         |
- name: update file
  hosts: all
  gather_facts: no
  become: yes
  vars:
    user_name: <<user_name>>
  tasks:
    - name: check the account exist
      ansible.builtin.shell: |
        id "{{ user_name }}"
      register: result
      failed_when: result.rc not in [0, 1]

    - name: exec update
      when: result.rc == 0
      block:
        - name: get target path
          ansible.builtin.shell:
            echo "<<target_file>>"
          register: get_result
          become_user: "{{ user_name }}"

        - name: set parameter
          ansible.builtin.set_fact:
            target_file: "{{ get_result.stdout }}"

        - name: setup hosts
          ansible.builtin.blockinfile:
            path: "{{ target_file }}"
            create: true
            marker: "# {mark} ANSIBLE MANAGED BLOCK <<suffix_marker>>"
            block: |
              <<input_content>>
          become_user: "{{ user_name }}" 
EOF
sed 's#<<user_name>>#'"${USER_NAME}"'#'                             |
sed 's#<<target_file>>#'"${TARGET_FILE}"'#'                         |
sed 's#<<suffix_marker>>#'"${SUFFIX_MARKER}"'#'                     |
awk '
  /<<input_content>>/ {
    while ((getline < "'"${CONTENT_FILE}"'") > 0) {
      printf "              %s\n", $0
    }
    next
  }
  { print }
'                                                                   |
cat >"${PLAYBOOK_FILE}"

if [ "${IS_DRYRUN}" = 'yes' ]; then
  cat "${PLAYBOOK_FILE}"
else
  ANSIBLE_PIPELINING=1 \
  ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"
fi
