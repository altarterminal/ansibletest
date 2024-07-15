#!/bin/sh
set -eu

#####################################################################
# setting
#####################################################################

THIS_DIR=$(dirname $0)
TOP_DIR="${THIS_DIR}/.."
DOCKER_DIR="${TOP_DIR}/dockertest/ubuntu"

if [ ! -d "${DOCKER_DIR}" ] || [ ! -x "${DOCKER_DIR}" ]; then
  echo "${0##*/}: <${DOCKER_DIR}> cannot be accessed" 1>&2
  exit 1
fi

#####################################################################
# main routine
#####################################################################

(
  cd "${DOCKER_DIR}"
  docker compose down
)
