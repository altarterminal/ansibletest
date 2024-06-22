#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} -i<ansible inventory> <ansible playbook>
Options :

execute <ansible playbook> with <ansible inventory> and parse the result
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

if [ ! -f "${opr}" ] || [ ! -r "${opr}" ]; then
  echo "${0##*/}: <${opr}> cannot be opened" 1>&2
  exit 1
fi

if [ ! -f "${opt_i}" ] || [ ! -r "${opt_i}" ]; then
  echo "${0##*/}: <${opt_i}> cannot be opened" 1>&2
  exit 1
fi

readonly PLAYBOOK_FILE=${opr}
readonly INVENTORY_FILE=${opt_i}

#####################################################################
# main routine
#####################################################################

ansible-playbook -i "${INVENTORY_FILE}" "${PLAYBOOK_FILE}"          |

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

# judge the result
awk '
{
  name = $1; host = $2; is_unreach = $3; is_fail = $4;

  if      (is_unreach != 0) { print name, host, "unreach"; }
  else if (is_fail    != 0) { print name, host, "fail";    }
  else                      { print name, host, "success"; }
}
'                                                                   |

# accumulate the NG hosts (if any)
awk '
{
  name = $1; host = $2; result = $3;

  if (result == "success") {
    failhost[name] = failhost[name] "";
  }
  else {
    if (failhost[name] == "") { failhost[name] =     host; }
    else                      { failhost[name] = "," host; }
  }
}

END {
  for (name in failhost) {
    if (failhost[name] == "") {
      printf "%s %s %s\n", name, "OK", "-";
    }
    else                      {
      printf "%s %s %s\n", name, "NG", failhost[name];
    }
  }
}
'
