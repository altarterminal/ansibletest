#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
cat <<-USAGE 1>&2
Usage   : ${0##*/} -i<inventory file>
Options :

execute command on multiple hosts on <inventory>

-i: specify the initial inventory file
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_i=''

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -i*)                 opt_i=${arg#-i}      ;; 
    *)
      if [ $i -eq $# ] && [ -z "$opr" ]; then
        opr=$arg
      else
        echo "${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if ! type ansible-playbook >/dev/null 2>&1; then
  echo "${0##*/}: ansible-playbook comannd cannot be found" 1>&2
  exit 1
fi

if [ ! -f "${opt_i}" ] || [ ! -r "${opt_i}" ]; then
  echo "${0##*/}: <${opt_i}> cannot be accessed for inventory" 1>&2
  exit 1
fi

readonly ORG_INVENTORY_FILE=${opt_i}
readonly NOW_DATE=$(date '+%Y%m%d%H%M%S')
readonly TEMPLATE_NAME=${TMP:-/tmp}/${0##*/}_${NOW_DATE}.XXXXXX.ini

readonly TOP_DIR=$(dirname $0)

#####################################################################
# prepare
#####################################################################

# inventory is tmporarily made for this system and 
# the original should not change
readonly INVENTORY_FILE=$(mktemp "${TEMPLATE_NAME}")
trap "[ -e ${INVENTORY_FILE} ] && rm ${INVENTORY_FILE}" EXIT
cp "${ORG_INVENTORY_FILE}" "${INVENTORY_FILE}"

#####################################################################
# unitility
#####################################################################

print_menu () {
cat <<'EOF'
h: print this menu
r: remove the unreachable host from inventory
c: execute shell command
q: quit
EOF
}

#####################################################################
# main routine
#####################################################################

while true
do
  printf '%s' 'menu ("h" for help) > '
  read -r cmd

  case "${cmd}" in
    h) print_menu ;;
    r) "${TOP_DIR}/remove_unreachhosts.sh" "${INVENTORY_FILE}" ;;
    c) "${TOP_DIR}/exec_command_if.sh" "${INVENTORY_FILE}" ;;
    q) exit 0 ;;
    *) ;;
  esac
done
