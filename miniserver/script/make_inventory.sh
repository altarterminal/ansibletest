#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <ledger>
Options :

make inventory files from <ledger>.
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
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
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

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "${0##*/}: <${opr}> cannot be accessed" 1>&2
  exit 1
fi

readonly LEDGER_FILE=${opr}

#####################################################################
# main routine
#####################################################################

# generate all vars
echo "[all]"
jq -c '.hostlist[]' "${LEDGER_FILE}"                                |
while read -r host; do
  host_name=$(echo "${host}" | jq -r '.name')
  host_ip=$(echo "${host}"   | jq -r '.ip')
  host_port=$(echo "${host}" | jq -r '.port')

  echo "${host_name} ansible_ip=${host_ip} ansible_port=${host_port}"
done
echo ""

# generate group
jq -c '.softlist[]' "${LEDGER_FILE}"                                |
while read -r soft; do
  soft_name=$(echo "${soft}" | jq -r '.name')

  # output target group
  echo "[hosts_${soft_name}]"
  echo "${soft}" | jq -rc '.hosts[]'
  echo ""

  # output complement group
  echo "[hosts_${soft_name}_complement]"
  jq -r '.hostlist.[].name' "${LEDGER_FILE}"                        |
  eval $(echo "${soft}"                                             |
         jq -rc '.hosts[]'                                          |
         xargs -I@ echo 'grep -v ^@$ | '                            |
         { cat; echo cat; }                                         )
  echo ""
done

# generate all vars
echo "[all:vars]"
echo "ansible_user=ansible"
