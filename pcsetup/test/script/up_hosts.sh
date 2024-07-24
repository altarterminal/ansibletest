#!/bin/sh
set -eu

#####################################################################
# parameter
#####################################################################

USER_NAME='ansible'
USER_ID='1234'
CONTAINER_NUM=1
PROXY=''

#####################################################################
# setting
#####################################################################

THIS_DIR=$(dirname $0)
TEST_DIR="${THIS_DIR}/.."

#####################################################################
# main routine
#####################################################################

(
  cd "${TEST_DIR}"

  if [ ! -e 'dockertest' ]; then
    git clone 'https://github.com/altarterminal/dockertest.git'
  else
    ( cd dockertest; git pull; )
  fi

  cd 'dockertest/ubuntu'
  ./script/setup.sh \
    -u"${USER_NAME}" -i"${USER_ID}" -n"${CONTAINER_NUM}" -x"${PROXY}"
  ./script/up_hosts.sh
)
