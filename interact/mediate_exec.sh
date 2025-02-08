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
readonly PREV_RESULT_NAME="${TMPDIR:-/tmp}/${0##*/}_${NOW_DATE}_XXXXXX"

#####################################################################
# prepare
#####################################################################

readonly PREV_RESULT_FILE="$(mktemp "${PREV_RESULT_NAME}")"

trap "
  [ -e ${PREV_RESULT_FILE} ] && rm ${PREV_RESULT_FILE}
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
---------------------------------------------------------------------
h: Show this message.
o: Switch the output of standard out.
e: Switch the output of standart error.
c: Switch the output of return code.
w: Write the previous result to a specified file.
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

  tee "${PREV_RESULT_FILE}"
)

output_file() (
  readonly CMD="$1"

  output_path=$(echo "${CMD}" | sed 's!^w  *!!')
  output_file=$(basename "${output_path}")
  output_dir=$(dirname "${output_path}")

  if ! mkdir -p "${output_dir}"; then
    echo "Failed to make a directory <${output_dir}>, so cannot write the result."
    return
  fi

  if [ -e "${output_path}" ]; then
    echo "The file of same name already exists <${output_file}>, so specify another."
    return
  fi

  cp "${PREV_RESULT_FILE}" "${output_path}"
)
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
      output_file "${cmd}"
      ;;
    *)
      exec_count=$((exec_count + 1))
      exec_command "${cmd}"
      ;;
  esac
done
