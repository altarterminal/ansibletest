#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/}
Options :

make an update playbook.
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

#####################################################################
# main routine
#####################################################################

echo "- name: Update"
echo "  hosts: all"
echo "  gather_facts: no"
echo "  become: yes"
echo "  tasks:"
echo "    - name: apt_update"
echo "      apt:"
echo "        update_cache: yes"
echo "        upgrade: yes"
