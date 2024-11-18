#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/} <venv path>
Options : -f

Setup python's venv on <venv path>.
If the baremetal environment of the virtual environment <env path>
include the ansible, nothing will be done.
Otherwise, ansible will be installed on <venv path>.

-f: enable force install (delete the existing directory).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_f='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -f)                  opt_f='yes'          ;;
    *)
      if [ $i -eq $# ]; then
        opr=${arg}
      else
        echo "ERROR:${0##*/}: invalid args" 1>&2
        exit 1
      fi
      ;;
  esac

  i=$((i + 1))
done

if type ansible >/dev/null 2>&1; then
  echo "INFO:${0##*/}: ansible has already been installed" 1>&2
  exit 0
fi

if ! type python3 >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: python3 not installed" 1>&2
  exit 1
fi

if [ -z "${opr}" ]; then
  echo "ERROR:${0##*/}: venv path must be specified" 1>&2
  exit 1
fi

readonly ENV_PATH="${opr}"
readonly IS_FORCE="${opt_f}"

readonly ACTIVATE_PATH="${ENV_PATH}/bin/activate"

#####################################################################
# prepare
#####################################################################

# delete the old environment if it is forced
if [ "${IS_FORCE}" = 'yes' ] && [ -d "${ENV_PATH}" ]; then
  rm -r "${ENV_PATH}"
  echo "INFO:${0##*/}: deleted the old environment <${ENV_PATH}>" 1>&2
fi

# check if the existing environment works for ansible
if [ -f "${ACTIVATE_PATH}" ] && [ -r "${ACTIVATE_PATH}" ]; then
  . "${ACTIVATE_PATH}"

  if type ansible >/dev/null 2>&1; then
    echo "INFO:${0##*/}: ansible is found on existing <${ENV_PATH}>" 1>&2
    exit 0
  fi

  deactivate
fi

# check if the environment path exists
if [ -d "${ENV_PATH}" ]; then
  echo "ERROR:${0##*/}: there is the existing directory <${ENV_PATH}>" 1>&2
  exit 1
fi

#####################################################################
# main routine
#####################################################################

# make an environment
mkdir -p "$(dirname "${ENV_PATH}")"
if ! python3 -m venv "${ENV_PATH}"; then
  echo "ERROR:${0##*/}: venv failed for some reasons" 1>&2
  exit 1
fi

# install the ansible
. "${ACTIVATE_PATH}"
if ! pip install ansible; then
  echo "ERROR:${0##*/}: installation of ansible by pip failed for reasons" 1>&2
  exit 1
fi

# check the ansible has been installed
if ! type ansible >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: ansible has not been installed for some reasons" 1>&2
  exit 1
fi

# reset the environment
deactivate
