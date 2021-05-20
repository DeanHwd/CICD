#!/bin/bash

set -eu

cd $(dirname $0)
SCRIPT_DIR="$(pwd)"

# Select docker or podman
if command -v docker > /dev/null; then
  DOCKER=docker
elif command -v podman > /dev/null; then
  DOCKER=podman
else
  echo "Please install docker or podman."
  exit 1
fi

# Select docker-compose or podman-compose
if command -v docker-compose > /dev/null; then
  COMPOSE=docker-compose
elif command -v podman-compose > /dev/null; then
  COMPOSE=podman-compose
else
  echo "Please install docker-compose or podman-compose."
  exit 1
fi


MYSQL="${DOCKER} exec zuul-test-mysql mysql  -u root -pinsecure_worker"

if [ "${COMPOSE}" == "docker-compose" ]; then
  docker-compose rm -sf
else
  podman-compose down
fi

CA_DIR=$SCRIPT_DIR/ca

mkdir -p $CA_DIR
$SCRIPT_DIR/zk-ca.sh $CA_DIR zuul-test-zookeeper

${COMPOSE} up -d

echo "Waiting for mysql"
timeout 30 bash -c "until ${MYSQL} -e 'show databases'; do sleep 0.5; done"
echo

echo "Setting up permissions for zuul tests"
${MYSQL} -e "GRANT ALL PRIVILEGES ON *.* TO 'openstack_citest'@'%' identified by 'openstack_citest' WITH GRANT OPTION;"
${MYSQL} -u openstack_citest -popenstack_citest -e "SET default_storage_engine=MYISAM; DROP DATABASE IF EXISTS openstack_citest; CREATE DATABASE openstack_citest CHARACTER SET utf8;"

echo "Finished"
