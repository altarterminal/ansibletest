#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -s<soft ledger> <host ledger>
Options :

make inventory files from <soft ledger> and <host ledger>.
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_s=''

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -s*)                 opt_s=${arg#-s}      ;;
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

if [ ! -f "${opt_s}" ] || [ ! -r "${opt_s}" ]; then
  echo "${0##*/}: <${opt_s}> cannot be accessed" 1>&2
  exit 1
fi

readonly HOST_LEDGER=${opr}
readonly SOFT_LEDGER=${opt_s}

#####################################################################
# main routine
#####################################################################

# generate all vars
echo "[all]"
jq -c '.[]' "${HOST_LEDGER}"                                        |
while read -r host; do
  host_name=$(echo "${host}" | jq -r '.name')
  host_ip=$(echo "${host}"   | jq -r '.ip')
  host_port=$(echo "${host}" | jq -r '.port // empty')
  host_user=$(echo "${host}" | jq -r '.user // empty')

  printf '%s' "${host_name} ansible_host=${host_ip}"
  [ -n "${host_port}" ] && printf ' ansible_port=%s' "${host_port}"
  [ -n "${host_user}" ] && printf ' ansible_user=%s' "${host_user}"
  echo ""
done
echo ""

# generate group
jq -c '.[]' "${SOFT_LEDGER}"                                        |
while read -r soft; do
  # extract info
  name=$(echo "${soft}" | jq -r '.name')
  hosts=$(echo "${soft}" | jq -rc '.hosts[]')
  chosts=$(jq -r '.[].name' "${HOST_LEDGER}"                        |
           eval $(echo "${soft}"                                    |
                  jq -rc '.hosts[]'                                 |
                  xargs -I@ echo 'grep -v ^@$ | '                   |
                  { cat; echo cat; }                               ))

  # output target group
  echo "[hosts_${name}]"
  echo "${hosts}"
  echo ""

  # output complement group
  echo "[hosts_${name}_complement]"
  echo "${chosts}"
  echo ""
done

# generate all vars
echo "[all:vars]"
echo "ansible_user=ansible"
