#!/bin/sh
set -eu

#####################################################################
# setting
#####################################################################

THIS_DIR=$(dirname $0)
TOP_DIR="${THIS_DIR}/.."

USER_NAME='ansible'
USER_ID='1234'

#####################################################################
# main routine
#####################################################################

(
  cd "${TOP_DIR}"
  git clone 'https://github.com/altarterminal/dockertest.git'
  cd 'dockertest/ubuntu'
  ./setup.sh -u"${USER_NAME}" -i"${USER_ID}"
  ./up_hosts.sh
)
