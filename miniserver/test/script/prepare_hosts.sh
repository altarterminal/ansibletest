#!/bin/sh
set -eu

###########################################################
# setting
###########################################################

DOCKER_TEMPLATE="./template/Dockerfile.template"
DOCKER_ENTITY="./dockerfile/Dockerfile"

DOCKER_USER='ansible'
DOCKER_UID='1234'

DOCKER_DIR=$(dirname ${DOCKER_ENTITY})

###########################################################
# main routine
###########################################################

mkdir -p "${DOCKER_DIR}"

cp "${HOME}/.ssh/id_rsa"     "${DOCKER_DIR}"
cp "${HOME}/.ssh/id_rsa.pub" "${DOCKER_DIR}"

cat "${DOCKER_TEMPLATE}"                                  |
sed 's!<<ansible_user>>!'"${DOCKER_USER}"'!'              |
sed 's!<<ansible_uid>>!'"${DOCKER_UID}"'!'                |
cat > "${DOCKER_ENTITY}"

docker compose up -d
