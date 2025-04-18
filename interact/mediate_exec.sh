#!/bin/sh
set -u

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options :

Execute command on hosts on <inventory file>
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr="${arg}"
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "ERROR:${0##*/}: invalid file specified <${opr}>" 1>&2
  exit 1
fi

readonly INVENTORY_FILE="${opr}"

readonly THIS_DIR="$(dirname "$0")"

readonly NOW_DATE="$(date '+%Y%m%d%H%M%S')"
readonly PREV_RESULT_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_prev_XXXXXX"
readonly GLOBAL_RESULT_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_global_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PREV_RESULT_FILE="$(mktemp "${PREV_RESULT_NAME}")"
readonly GLOBAL_RESULT_FILE="$(mktemp "${GLOBAL_RESULT_NAME}")"

trap "
  [ -e ${PREV_RESULT_FILE} ] && rm ${PREV_RESULT_FILE}
  [ -e ${GLOBAL_RESULT_FILE} ] && rm ${GLOBAL_RESULT_FILE}
" EXIT

#####################################################################
# utility
#####################################################################

is_stdout='yes'
is_stderr='yes'
is_rtcode='yes'

exec_count='0'

print_state() (
cat<<EOF
#####################################################################
Standard Out: $(echo ${is_stdout} | tr 'a-z' 'A-Z')
Standard Err: $(echo ${is_stderr} | tr 'a-z' 'A-Z')
Return Code:  $(echo ${is_rtcode} | tr 'a-z' 'A-Z')
Execution Count: ${exec_count}
---------------------------------------------------------------------
h: Show this message.
o: Switch the output of standard out.
e: Switch the output of standart error.
c: Switch the output of return code.
w: Write the log of previous result to a specified file.
W: Write the log of all result to a specified file.
r: Reset the log of all past result.
q: Quit.
#####################################################################
EOF
)

exec_command() (
  readonly CMD="$1"

  if [ "${is_stdout}${is_stderr}${is_rtcode}" = 'nonono' ]; then
    echo "Please enable at least one output"
    return
  fi

  if [ "${is_stdout}" = 'yes' ]; then stdout_opt='-so'; else stdout_opt=''; fi
  if [ "${is_stderr}" = 'yes' ]; then stderr_opt='-se'; else stderr_opt=''; fi
  if [ "${is_rtcode}" = 'yes' ]; then rtcode_opt='-rc'; else rtcode_opt=''; fi

  "${THIS_DIR}/exec_command.sh"                                     \
    ${stdout_opt} ${stderr_opt} ${rtcode_opt}                       \
   "${INVENTORY_FILE}" "${CMD}"                                     |

  sed 's!^!'"${exec_count}"'<N>!'                                   |

  tee "${PREV_RESULT_FILE}"                                         |
  tee -a "${GLOBAL_RESULT_FILE}"
)

write_log() (
  readonly TYPE="$1"
  readonly OUT_PATH="$2"

  out_file=$(basename "${OUT_PATH}")
  out_dir=$(dirname "${OUT_PATH}")

  if ! mkdir -p "${out_dir}"; then
    echo "Failed to make a directory <${out_dir}>, so cannot write the result."
    return
  fi

  if [ -e "${OUT_PATH}" ]; then
    echo "The file of same name already exists <${out_file}>, so specify another."
    return
  fi

  if   [ "${TYPE}" = 'prev' ]; then
    cp "${PREV_RESULT_FILE}"   "${OUT_PATH}"
  elif [ "${TYPE}" = 'global' ]; then
    cp "${GLOBAL_RESULT_FILE}" "${OUT_PATH}"
  else
    echo "ERROR:${0##*/}: invalid type specified <${TYPE}>" 1>&2
    exit 1
  fi
)

reset_global_log() {
  : >"${GLOBAL_RESULT_FILE}"
}

#####################################################################
# main routine
#####################################################################

print_state

while true
do
  printf 'command ("h" for help) > '
  read -r cmd

  case "${cmd}" in
    h)
      print_state
      ;;
    q)
      exit 0
      ;;
    o|o\ *)
      if [ "${is_stdout}" = 'no' ]; then
        is_stdout='yes'; echo "Enabled standard out"
      else
        is_stdout='no';  echo "Disabled standard out"
      fi
      ;;
    e|e\ *)
      if [ "${is_stderr}" = 'no' ]; then
        is_stderr='yes'; echo "Enabled standard error"
      else
        is_stderr='no';  echo "Disabled standard error"
      fi
      ;;
    c|c\ *)
      if [ "${is_rtcode}" = 'no' ]; then
        is_rtcode='yes'; echo "Enabled return code"
      else
        is_rtcode='no';  echo "Disabled return code"
      fi
      ;;
    w\ *)
      write_log 'prev'   "$(printf '%s\n' "${cmd}" | sed 's/^w *//')"
      ;;
    W\ *)
      write_log 'global' "$(printf '%s\n' "${cmd}" | sed 's/^W *//')"
      ;;
    r|r\ *)
      reset_global_log
      ;;
    *)
      exec_count=$((exec_count + 1))
      exec_command "${cmd}"
      ;;
  esac
done
