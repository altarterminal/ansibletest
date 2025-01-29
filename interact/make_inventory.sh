#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <host ledger>
Options : -u<ansible user>

Make a inventory file from <host ledger>.

-u: Specify the default user for ansible (default: <$(whoami)> = who executes this).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_u="$(whoami)"

i=1
for arg in ${1+"$@"}
do
  case "$arg" in
    -h|--help|--version) print_usage_and_exit ;;
    -u*)                 opt_u=${arg#-u}      ;;
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

if [ -z "${opt_u}" ]; then
  echo "ERROR:${0##*/}: user must be specified" 1>&2
  exit 1
fi

readonly HOST_LEDGER="${opr}"
readonly ANSIBLE_USER="${opt_u}"

#####################################################################
# main routine
#####################################################################

# generate each vars
echo "[all]"
jq -c '.[]' "${HOST_LEDGER}"                                        |
while read -r host; do
  host_validity=$(echo "${host}" | jq -r '.validity // empty')

  if [ "${host_validity}" != 'true' ] && [ "${host_validity}" != '' ]; then
    continue
  fi

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

# generate all vars
echo "[all:vars]"
echo "ansible_port=22"
echo "ansible_user=${ANSIBLE_USER}"
