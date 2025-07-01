#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/}
Options : -o<output path> -f

Prepare ansible.cfg to <output path>.
Do nothing if the file already exists.

-o: Specify the output file path (default: ./ansible.cfg).
-f: Enable the overwrite when the file already exists.
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opt_o='./ansible.cfg'
opt_f='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -o*)                 opt_o="${arg#-o}"    ;;
    -f)                  opt_f='yes'          ;;
    *)
      echo "ERROR:${0##*/}: invalid args" 1>&2
      exit 1
      ;;
  esac

  i=$((i + 1))
done

if [ -z "${opt_o}" ]; then
  echo "ERROR:${0##*/}: output path must be specified" 1>&2
  exit 1
fi

CONFIG_FILE="${opt_o}"
IS_FORCE="${opt_f}"

#####################################################################
# prepare
#####################################################################

if [ "${IS_FORCE}" = 'yes' ] && [ -e "${CONFIG_FILE}" ]; then
  rm "${CONFIG_FILE}"
fi

#####################################################################
# main routine
#####################################################################

if [ -e "${CONFIG_FILE}" ]; then
  echo "INFO:${0##*/}: there is already <${CONFIG_FILE}> and nothing is done" 1>&2
  exit
fi

cat <<'EOF'                                                         |
[defaults]
ask_pass = False
host_key_checking = False
EOF
cat >"${CONFIG_FILE}"
