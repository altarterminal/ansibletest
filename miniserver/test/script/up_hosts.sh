#!/bin/sh
set -eu

#####################################################################
# setting
#####################################################################

THIS_DIR=$(dirname $0)

TEMPLATE_DIR="${THIS_DIR}/../template"
DOCKER_DIR="${THIS_DIR}/../dockerfile"

DOCKER_TEMPLATE="${TEMPLATE_DIR}/Dockerfile.template"
DOCKER_ENTITY="${DOCKER_DIR}/Dockerfile"

DOCKER_USER='ansible'
DOCKER_UID='1234'

#####################################################################
# main routine
#####################################################################

mkdir -p "${DOCKER_DIR}"

cp "${HOME}/.ssh/id_rsa"     "${DOCKER_DIR}"
cp "${HOME}/.ssh/id_rsa.pub" "${DOCKER_DIR}"

cat "${DOCKER_TEMPLATE}"                                            |
sed 's!<<ansible_user>>!'"${DOCKER_USER}"'!'                        |
sed 's!<<ansible_uid>>!'"${DOCKER_UID}"'!'                          |
cat > "${DOCKER_ENTITY}"

(
  cd "${THIS_DIR}"
  docker compose up -d
)
