#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <ansible result>
Options :

parse <ansible result> and output when some error occurs
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

if [ "_${opr}" = '_' ] || [ "_${opr}" = '_-' ]; then
  opr=''
elif [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "${0##*/}: <${opr}> cannot be opened" 1>&2
  exit 1
fi

readonly RESULT_FILE=${opr}

#####################################################################
# main routine
#####################################################################

cat ${RESULT_FILE:+"${RESULT_FILE}"}                                |

awk '
/^PLAY \[[^]]*\] / {
  sub(/^PLAY \[/, "", $0); sub(/\] .*$/, "", $0);
  soft = $0;
}

/^PLAY RECAP /,/^$/ {
  print soft, $0;
}
'                                                                   |
sed '1d;$d'                                                         |
tr -d ':'                                                           |
tr '=' ' '                                                          |
awk '{ print $1, $2, $8, $(10); }'                                  |

awk '
$3 != 0 { print $1, $2, "unreach"; }
$4 != 0 { print $1, $2, "fail";    }
'
