#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory> <script>
Options : -u<user name> -so -se -rc

Execute shell scirpt <script> on <inventory>.
Input the script contents from stdin if the <script> is -.

-u: Specify the user name to execute the script on hosts (default: $(whoami)).
-c: Check the grammer before execution with shellcheck.
-so: Enable the output of standard out (default: disabled).
-se: Enable the output of standard error (default: disabled).
-rc: Enable the output of return code as number (default: disabled).

Note.
  If all of -so, -se and -rc are NOT specified, all of them are enabled automaticaly.
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr_i=''
opr_s=''
opt_u=$(whoami)
opt_c='no'
opt_so='no'
opt_se='no'
opt_rc='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
    -c)                  opt_c='yes'          ;;
    -so)                 opt_so='yes'         ;;
    -se)                 opt_se='yes'         ;;
    -rc)                 opt_rc='yes'         ;;
    *)
      if  [ $i -eq $(($# - 1)) ] && [ -z "${opr_i}" ]; then
        opr_i="${arg}"
      elif [ $i -eq $# ] && [ -z "${opr_s}" ]; then
        opr_s="${arg}"
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if ! type ansible-playbook >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: ansible command not found" 1>&2
  exit 1
fi

if [ ! -f "${opr_i}" ] || [ ! -r "${opr_i}" ]; then
  echo "ERROR:${0##*/}: invalid inventory specified <${opr_i}>" 1>&2
  exit 1
fi

if   [ "${opr_s}" = '' ]; then
  echo "ERROR:${0##*/}: script must be specified" 1>&2
  exit 1
elif [ "${opr_s}" = '-' ]; then
  :
else
  if [ ! -f "${opr_s}" ] || [ ! -r "${opr_s}" ]; then
    echo "ERROR:${0##*/}: invalid script specified <${opr_s}>" 1>&2
    exit 1
  fi

  if ! echo "${opr_s}" | grep -q '\.sh$'; then
    echo "ERROR:${0##*/}: input script should have the extension <.sh>" 1>&2
    exit 1
  fi

  opr_s="$(realpath "${opr_s}")"
fi

if [ -z "${opt_u}" ]; then
  echo "ERROR:${0##*/}: user name must be specified" 1>&2
  exit 1
fi

if [ "${opt_so}${opt_se}${opt_rc}" = 'nonono' ]; then
  readonly IS_STDOUT='yes'
  readonly IS_STDERR='yes'
  readonly IS_RTCODE='yes'
else
  readonly IS_STDOUT="${opt_so}"
  readonly IS_STDERR="${opt_se}"
  readonly IS_RTCODE="${opt_rc}"
fi

readonly INVENTORY_FILE="${opr_i}"
readonly SH_FILE="${opr_s}"
readonly USER_NAME="${opt_u}"
readonly IS_CHECK="${opt_c}"

#####################################################################
# setting
#####################################################################

readonly DATE=$(date '+%Y%m%d_%H%M%S')
readonly TEMP_PLAYBOOK_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_playbook_XXXXXX"
readonly TEMP_SH_NAME="${TMPDIR:-/tmp}/${0##*/}_${DATE}_script_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PLAYBOOK_FILE=$(mktemp "${TEMP_PLAYBOOK_NAME}")
readonly SH_MIDDLE_FILE=$(mktemp "${TEMP_SH_NAME}")

trap "
  [ -e ${PLAYBOOK_FILE} ] && rm ${PLAYBOOK_FILE}
  [ -e ${SH_MIDDLE_FILE} ] && rm ${SH_MIDDLE_FILE}
" EXIT

cat ${SH_FILE} >"${SH_MIDDLE_FILE}"

if [ "${IS_CHECK}" = 'yes' ]; then
  if ! type shellcheck >/dev/null 2>&1; then
    echo "ERROR:${0##*/}: shellcheck command not found" 1>&2
    exit 1
  fi

  if ! shellcheck -S error "${SH_MIDDLE_FILE}" >/dev/null 2>&1; then
    echo "ERROR:${0##*/}: shellcheck detected grammer error" 1>&2
    exit 1
  fi
fi

#####################################################################
# main routine
#####################################################################

cat <<'EOF'                                                         |
- name: execute script
  hosts: all
  gather_facts: no
  become: yes
  vars:
    sh_script: "<<sh_script>>" 
    user_name: "<<user_name>>"
  tasks:
  - name: check the user exists
    ansible.builtin.shell: |
      id "{{ user_name }}"

  - name: execute script
    ansible.builtin.shell: |
      {{ lookup('ansible.builtin.file', sh_script) }}
    become_user: "{{ user_name }}"
EOF
sed 's!<<sh_script>>!'"${SH_MIDDLE_FILE}"'!'                        |
sed 's!<<user_name>>!'"${USER_NAME}"'!'                             |
cat >"${PLAYBOOK_FILE}"

ANSIBLE_SHELL_ALLOW_WORLD_READABLE_TEMP=1                           \
ansible-playbook -v -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"       |

sed -n '/^TASK \[execute/,/^$/p'                                    |
sed '1d;$d'                                                         |

sed 's/^.*: \[\(.*\)\] => \(.*\)/{"hostname":"\1","result":"OK","state":\2}/'                 |
sed 's/^fatal: \[\(.*\)\]: \([A-Z]*\)! => \(.*\)/{"hostname":"\1","result":"\2","state":\3}/' |

# sort by hostname
jq -s .                                                             |
jq '. | sort_by(.hostname)'                                         |
jq -c '.[]'                                                         |

while read -r line
do
  hostname=$(printf '%s' "${line}" | jq -r '.hostname')
  result=$(printf '%s' "${line}"   | jq -r '.result')

  if   [ "${result}" = 'OK' ] || [ "${result}" = 'FAILED' ] ; then
    stdout_line="$(printf '%s\n' "${line}" | jq -r '.state.stdout')"
    stderr_line="$(printf '%s\n' "${line}" | jq -r '.state.stderr')"
    rtcode_line="$(printf '%s\n' "${line}" | jq -r '.state.rc')"
  elif [ "${result}" = 'UNREACHABLE' ]; then
    stdout_line=''
    stderr_line="$(printf '%s\n' "${line}" | jq -r '.state.msg')"
    rtcode_line='255'
  else
    echo "ERROR:${0##*/}: unexpected result <${result}> (skip)" 1>&2
    continue
  fi

  {
    if [ "${IS_STDOUT}" = 'yes' ]; then
      printf '%s\n' "${stdout_line}" | sed 's!^!stdout<T>!'
    fi
    if [ "${IS_STDERR}" = 'yes' ]; then
      printf '%s\n' "${stderr_line}" | sed 's!^!stderr<T>!'
    fi
    if [ "${IS_RTCODE}" = 'yes' ]; then
      printf '%s\n' "${rtcode_line}" | sed 's!^!rtcode<T>!'
    fi
  }                                                                 |
  sed 's!^!'"${hostname}"'<M>!'
done
