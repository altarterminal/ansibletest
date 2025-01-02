#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/}
Options : -e<env path> -c<config path> -k<sshkey path> -o<out name>

Prepare the whole ansible setting.
Output the script name to stdout to enable it when you source.

-e: specify the venv path (default: ./ansible_env)
-c: specify the config file path (default: ./ansible.cfg)
-k: specify the ssh secret key path (default: ./ansible_sshkey)
-o: specify the output file name to enable ansible (default: ./ansible_enable.sh)
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_e='./ansible_env'
opt_c='./ansible.cfg'
opt_k='./ansible_sshkey'
opt_o='./ansible_enable.sh'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -e*)                 opt_e=${arg#-e}      ;;
    -c*)                 opt_c=${arg#-c}      ;;
    -k*)                 opt_k=${arg#-k}      ;;
    -o*)                 opt_o=${arg#-o}      ;;
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

if [ -z "${opt_e}" ]; then
  echo "ERROR:${0##*/}: venv path must be specified" 1>&2
  exit 1
fi

if [ -z "${opt_c}" ]; then
  echo "ERROR:${0##*/}: config path must be specified" 1>&2
  exit 1
fi

if [ -z "${opt_k}" ]; then
  echo "ERROR:${0##*/}: ssh key path must be specified" 1>&2
  exit 1
fi

if [ -z "${opt_o}" ]; then
  echo "ERROR:${0##*/}: output file name must be specified" 1>&2
  exit 1
fi

readonly ENV_PATH="${opt_e}"
readonly CONFIG_PATH="${opt_c}"
readonly KEY_PATH="${opt_k}"
readonly OUT_FILE="${opt_o}"

readonly THIS_DIR="${0%/*}"

#####################################################################
# main routine
#####################################################################

if ! "${THIS_DIR}/setup_command.sh" "${ENV_PATH}"; then
  echo "ERROR:${0##*/}: command setup failed" 1>&2
  exit 1
fi

if ! "${THIS_DIR}/setup_config.sh" -o"${CONFIG_PATH}"; then
  echo "ERROR:${0##*/}: config setup failed" 1>&2
  exit 1
fi

if ! "${THIS_DIR}/setup_sshkey.sh" -o"${KEY_PATH}"; then
  echo "ERROR:${0##*/}: sshkey setup failed" 1>&2
  exit 1
fi

#####################################################################
# main routine
#####################################################################

{
  if ! type ansible >/dev/null 2>&1; then
    echo '. '"$(realpath "${ENV_PATH}/bin/activate")"
  fi

  echo 'export ANSIBLE_CONFIG='"$(realpath "${CONFIG_PATH}")"
  echo 'export ANSIBLE_PRIVATE_KEY_FILE='"$(realpath "${KEY_PATH}")"
} >"${OUT_FILE}"

echo "$(realpath "${OUT_FILE}")"
