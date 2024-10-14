#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/}
Options : -d<output dir>

make an update playbook.

-d: specify the <output dir> into which output a playbook
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_d='.'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -d*)                 opt_d=${arg#-d}      ;;
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

[ ! -e "${opt_d}" ] && mkdir -p "${opt_d}"
if [ ! -d "${opt_d}" ] || [ ! -w "${opt_d}" ]; then
  echo "ERROR:${0##*/}: <${opt_d}> is an invalid directory" 1>&2
  exit 1
fi

readonly OUTPUT_DIR=${opt_d%/}

#####################################################################
# main routine
#####################################################################

{
  echo "- name: Update"
  echo "  hosts: all"
  echo "  gather_facts: no"
  echo "  become: yes"
  echo "  tasks:"
  echo "    - name: apt_update"
  echo "      apt:"
  echo "        update_cache: yes"
  echo "        upgrade: yes"
} >"${OUTPUT_DIR}/playbook_update.yml"
