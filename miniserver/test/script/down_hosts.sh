#!/bin/sh
set -eu

#####################################################################
# setting
#####################################################################

THIS_DIR=$(dirname $0)
COMPOSE_DIR="${THIS_DIR}/.."

#####################################################################
# main routine
#####################################################################

(
  cd "${COMPOSE_DIR}"
  docker compose down
)
