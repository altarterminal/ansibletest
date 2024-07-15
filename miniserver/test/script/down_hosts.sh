#!/bin/sh
set -eu

#####################################################################
# setting
#####################################################################

THIS_DIR=$(dirname $0)
TEST_DIR="${THIS_DIR}/.."
DOCKER_DIR="${TEST_DIR}/dockertest/ubuntu"

if [ ! -d "${DOCKER_DIR}" ] || [ ! -x "${DOCKER_DIR}" ]; then
  echo "${0##*/}: <${DOCKER_DIR}> cannot be accessed" 1>&2
  exit 1
fi

#####################################################################
# main routine
#####################################################################

(
  cd "${DOCKER_DIR}"
  ./script/down_hosts.sh
)
