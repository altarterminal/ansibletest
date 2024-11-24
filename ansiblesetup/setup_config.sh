#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/}
Options : -o<output path> -f

Prepare ansible.cfg to <output path>

-o: specify the output file path (default: ./ansible.cfg)
-f: enable the overwrite when the file has already exist
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_o='./ansible.cfg'
opt_f='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -o*)                 opt_o=${arg#-o}      ;;
    -f)                  opt_f='yes'          ;;
    *)
      if [ $i -eq $# ] && [ -z "${opr}" ]; then
        opr=${arg}
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if [ -z "${opt_o}" ]; then
  echo "ERROR:${0##*/}: output path must be specified" 1>&2
  exit 1
fi

readonly CONFIG_FILE=${opt_o}
readonly IS_FORCE=${opt_f}

#####################################################################
# prepare
#####################################################################

if [ -f "${CONFIG_FILE}" ]; then
  if [ "${IS_FORCE}" = 'yes' ]; then
    echo "INFO:${0##*/}: overwrite the existing <${CONFIG_FILE}>" 1>&2
  else
    echo "ERROR:${0##*/}: there has already been <${CONFIG_FILE}>" 1>&2
    exit 1
  fi
fi

#####################################################################
# main routine
#####################################################################

cat <<'EOF'                                                         |
[defaults]
ask_pass = False
host_key_checking = False
EOF
cat >"${CONFIG_FILE}"
