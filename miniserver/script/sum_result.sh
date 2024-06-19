#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <parsed result>
Options :

parse <parsed result> and output the combination of soft and result
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
{
  name = $1;
  if (name ~/_complement$/) { sub(/_complement$/, "", $1); print; }
  else                      {                              print; }
}
'                                                                   |

sort                                                                |

awk '
{
  name = $1; host = $2; result = $3;

  if (result != "success") {
    if (failhost[name] == "") { failhost[name] =     host; }
    else                      { failhost[name] = "," host; }
  } 
  else {
    failhost[name] = failhost[name] "";
  }
}

END {
  for (name in failhost) {
    if (failhost[name] == "") { print name, "OK";                 }
    else                      { print name, "NG", failhost[name]; }
  }
}
'
