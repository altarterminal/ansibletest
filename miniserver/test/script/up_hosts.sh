#!/bin/sh
set -eu

#####################################################################
# setting
#####################################################################

THIS_DIR=$(dirname $0)
TEST_DIR="${THIS_DIR}/.."

USER_NAME='ansible'
USER_ID='1234'
CONTAINER_NUM=3

#####################################################################
# main routine
#####################################################################

(
  cd "${TEST_DIR}"
  git clone 'https://github.com/altarterminal/dockertest.git'
  cd 'dockertest/ubuntu'
  ./script/setup.sh -u"${USER_NAME}" -i"${USER_ID}" -n"${CONTAINER_NUM}"
  ./script/up_hosts.sh
)
