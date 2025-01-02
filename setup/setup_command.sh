#!/bin/sh
set -eu

#####################################################################
# help
#####################################################################

print_usage_and_exit () {
  cat <<-USAGE 1>&2
Usage   : ${0##*/}
Options : -o<output path> -f

Setup python's venv on <output path>.
Do nothing if the baremetal environment or the existing virtual environment <output path> include the ansible
Otherwise, ansible will be installed on <output path>.

-o: Specify the virtual environment path (default: ./ansible_env).
-f: Enable force install (delete the existing virtual environment).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opr=''
opt_o='./ansible_env'
opt_f='no'

i=1
for arg in ${1+"$@"}
do
  case "${arg}" in
    -h|--help|--version) print_usage_and_exit ;;
    -o*)                 opt_o=${arg#-o}      ;;
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

if ! type python3 >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: python3 not installed" 1>&2
  exit 1
fi

if [ -z "${opt_o}" ]; then
  echo "ERROR:${0##*/}: venv path must be specified" 1>&2
  exit 1
fi

readonly ENV_PATH="${opt_o}"
readonly IS_FORCE="${opt_f}"

readonly ACTIVATE_PATH="${ENV_PATH}/bin/activate"

#####################################################################
# prepare
#####################################################################

# check the baremetal ansible
if type ansible >/dev/null 2>&1; then
  echo "INFO:${0##*/}: ansible command found and nothing is done" 1>&2
  exit 0
fi

if [ "${IS_FORCE}" = 'yes' ] && [ -d "${ENV_PATH}" ]; then
  rm -r "${ENV_PATH}"
fi

# check if the existing directory is virtual environment
if [ -e "${ENV_PATH}" ] && [ ! -e "${ACTIVATE_PATH}" ]; then
  echo "ERROR:${0##*/}: existing path is not virtual environment" 1>&2
  exit 1
fi

# check if the existing virtual environment includes ansible
if [ -f "${ACTIVATE_PATH}" ] && [ -r "${ACTIVATE_PATH}" ]; then
  . "${ACTIVATE_PATH}"

  if type ansible >/dev/null 2>&1; then
    echo "INFO:${0##*/}: ansible found on existing <${ENV_PATH}>" 1>&2
    exit 0
  fi

  deactivate
fi

#####################################################################
# main routine
#####################################################################

if [ ! -e "${ENV_PATH}" ]; then
  echo "INFO:${0##*/}: start -> make a virtual environemnt" 1>&2

  mkdir -p "$(dirname "${ENV_PATH}")"
  if ! python3 -m venv "${ENV_PATH}"; then
    echo "ERROR:${0##*/}: venv failed for some reasons" 1>&2
    exit 1
  fi

  echo "INFO:${0##*/}: end   -> make a virtual environemnt" 1>&2
fi

. "${ACTIVATE_PATH}"

echo "INFO:${0##*/}: start -> install ansible on virtual environemnt" 1>&2

if ! pip -q install ansible; then
  echo "ERROR:${0##*/}: installation of ansible by pip failed for reasons" 1>&2
  exit 1
fi

echo "INFO:${0##*/}: end   -> install ansible on virtual environemnt" 1>&2

#####################################################################
# post
#####################################################################

if ! type ansible >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: ansible has not been installed for some reasons" 1>&2
  exit 1
fi

# reset the environment
deactivate
