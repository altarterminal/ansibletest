#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -s<soft ledger> <host ledger>
Options :

make complement of <soft ledege> from <soft ledger> and <host ledger>.
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

jq -c '.[]' "${SOFT_LEDGER}"                                        |
while read -r soft; do
  name=$(echo "${soft}" | jq -r '.name')
  cmd=$(echo "${soft}"  | jq -r '.cmd')
  chosts=$(jq -r '.[].name' "${HOST_LEDGER}"                        |
           eval $(echo "${soft}"                                    |
                  jq -rc '.hosts[]'                                 |
                  xargs -I@ echo 'grep -v ^@$ | '                   |
                  { cat; echo 'cat'; })                             |
           jq -R .                                                  |
           jq -cs .                                                 )

  printf '{"name":"%s", "cmd":"%s", "hosts":%s},\n'                 \
         "${name}" "${cmd}" "${chosts}"
done                                                                |

{
  printf '[\n'
  cat
  printf '{"name":"dummy", "cmd":"dummy", "hosts":["dummy"]}'
  printf ']\n'
}                                                                   |

jq '.[0:-1]'
