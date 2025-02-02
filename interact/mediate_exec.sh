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

readonly THIS_DIR=$(dirname $0)

#####################################################################
# main routine
#####################################################################

stdout_opt=''
stderr_opt=''
rtcode_opt=''

while true
do
  printf 'execute command ("q" for quit) > '
  read -r cmd

  case "${cmd}" in
    q)
      exit 0 ;;
    o|'o *')
      if [ -z "${stdout_opt}" ]; then
        stdout_opt='-so'
        echo "Enabled standard out"
      else
        stdout_opt=''
        echo "Disabled standard out"
      fi
      ;;
    e|'e *')
      if [ -z "${stderr_opt}" ]; then
        stderr_opt='-se'
        echo "Enabled standard error"
      else
        stderr_opt=''
        echo "Disabled standard error"
      fi
      ;;
    c|'c *')
      if [ -z "${rtcode_opt}" ]; then
        rtcode_opt='-rc'
        echo "Enabled return code"
      else
        rtcode_opt=''
        echo "Disabled return code"
      fi
      ;;
    *)
      "${THIS_DIR}/exec_command.sh"                                 \
        ${stdout_opt} ${stderr_opt} ${rtcode_opt}                   \
        "${INVENTORY_FILE}" "${cmd}" ;;
  esac
done
