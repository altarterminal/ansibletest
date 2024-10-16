#!/bin/sh
set -u

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <inventory file>
Options :

execute command on hosts on <inventory file>
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
        opr=$arg
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "ERROR:${0##*/}: <${opr}> cannot be accessed for inventory" 1>&2
  exit 1
fi

readonly INVENTORY_FILE=${opr}

#####################################################################
# main routine
#####################################################################

while true
do
  printf '%s' 'execute command ("q" for quit) > '
  read -r cmd

  case "${cmd}" in
    q) exit 0 ;;
    *) exec_command -i"${INVENTORY_FILE}" "${cmd}" ;;
  esac
done
