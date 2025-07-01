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

Install required packages on virtual environment <output path>.
- ansible
- passlib

-o: Specify the virtual environment path (default: ./ansible_venv).
-f: Enable force install (delete the existing virtual environment).
USAGE
  exit 1
}

#####################################################################
# parameter
#####################################################################

opt_o='./ansible_venv'
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

if ! type python3 >/dev/null 2>&1; then
  echo "ERROR:${0##*/}: python3 command not found" 1>&2
  exit 1
fi

if [ -z "${opt_o}" ]; then
  echo "ERROR:${0##*/}: venv path must be specified" 1>&2
  exit 1
fi

ENV_PATH="${opt_o}"
IS_FORCE="${opt_f}"

#####################################################################
# setting
#####################################################################

ACTIVATE_PATH="${ENV_PATH}/bin/activate"

#####################################################################
# prepare
#####################################################################

if [ "${IS_FORCE}" = 'yes' ] && [ -d "${ENV_PATH}" ]; then
  rm -r "${ENV_PATH}"
fi

# check if the existing directory is virtual environment
if [ -e "${ENV_PATH}" ] && [ ! -e "${ACTIVATE_PATH}" ]; then
  echo "ERROR:${0##*/}: existing path is not virtual environment" 1>&2
  exit 1
fi

#####################################################################
# main routine
#####################################################################

if [ ! -e "${ENV_PATH}" ]; then
  echo "INFO:${0##*/}: start -> make a new virtual environemnt" 1>&2

  mkdir -p "$(dirname "${ENV_PATH}")"
  if ! python3 -m venv "${ENV_PATH}"; then
    echo "ERROR:${0##*/}: venv failed for some reason" 1>&2
    exit 1
  fi

  echo "INFO:${0##*/}: end   -> make a new virtual environemnt" 1>&2
fi

. "${ACTIVATE_PATH}"

echo "INFO:${0##*/}: start -> install required component" 1>&2

if ! pip3 -q install ansible passlib; then
  echo "ERROR:${0##*/}: installation by pip failed for some reason" 1>&2
  exit 1
fi

echo "INFO:${0##*/}: end   -> install required component" 1>&2

#####################################################################
# post
#####################################################################

# reset the environment
deactivate
