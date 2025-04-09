#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file> <command>
Options : -u<user name> -so -se -rc

Execute <command> on hosts on <inventory file>.

-u:  Specify the user name to execute command (default: <$(whoami)> = who executes this).
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
opr_c=''
opt_u="$(whoami)"
opt_so='no'
opt_se='no'
opt_rc='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u="${arg#-u}"    ;;
    -so)                 opt_so='yes'         ;;
    -se)                 opt_se='yes'         ;;
    -rc)                 opt_rc='yes'         ;;
    *)
      if [ $i -eq $(($# - 1)) ] && [ -z "${opr_i}" ]; then
        opr_i="${arg}"
      elif [ $i -eq $# ] && [ -z "${opr_c}" ]; then
        opr_c="${arg}"
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if [ ! -f "${opr_i}" ] || [ ! -r "${opr_i}" ]; then
  echo "ERROR:${0##*/}: invalid inventory specified <${opr_i}>" 1>&2
  exit 1
fi

if [ -z "${opr_c}" ]; then
  echo "ERROR:${0##*/}: command must be specified" 1>&2
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
readonly COMMAND_STRING="${opr_c}"
readonly USER_NAME="${opt_u}"

#####################################################################
# setting
#####################################################################

THIS_DIR="$(dirname "$0")"
SCRIPT_TOOL="${THIS_DIR}/exec_script.sh"

#####################################################################
# check
#####################################################################

if [ ! -e "${SCRIPT_TOOL}" ]; then
  echo "ERROR:${0##*/}: required tool not found <${SCRIPT_TOOL}>" 1>&2
  exit 1
fi

#####################################################################
# prepare
#####################################################################

if [ "${IS_STDOUT}" = 'yes' ]; then
  STDOUT_OPT='-so'
else
  STDOUT_OPT=''
fi

if [ "${IS_STDERR}" = 'yes' ]; then
  STDERR_OPT='-se'
else
  STDERR_OPT=''
fi

if [ "${IS_RTCODE}" = 'yes' ]; then
  RTCODE_OPT='-rc'
else
  RTCODE_OPT=''
fi

#####################################################################
# main routine
#####################################################################

printf '%s\n' "${COMMAND_STRING}"                                   |

"${SCRIPT_TOOL}"                                                    \
  ${STDOUT_OPT} ${STDERR_OPT} ${RTCODE_OPT}                         \
  -u"${USER_NAME}" "${INVENTORY_FILE}" - 
