#!/bin/bash
# Copyright 2017 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ZUUL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# Initialize tox environment if it's not set up
if [[ ! -d "${ZUUL_DIR}/.tox/venv" ]]; then
    pushd $ZUUL_DIR
        echo "Virtualenv doesn't exist... creating."
        tox -e venv --notest
    popd
fi

ANSIBLE_VERSION="2.7"
ANSIBLE_ROOT="${ZUUL_DIR}/.tox/venv/lib/zuul/ansible/${ANSIBLE_VERSION}"
ARA_DIR=$(dirname $("${ANSIBLE_ROOT}/bin/python3" -c 'import ara; print(ara.__file__)'))

# Source tox environment
source ${ZUUL_DIR}/.tox/venv/bin/activate

WORK_DIR=$(mktemp -d /tmp/zuul_logs_XXXX)

# Copy zuul ansible modules into workdir
ZUUL_ANSIBLE="${WORK_DIR}/zuul-ansible"
mkdir -p "${ZUUL_ANSIBLE}/zuul"
cp -Lr "${ZUUL_DIR}/zuul/ansible/${ANSIBLE_VERSION}" "${ZUUL_ANSIBLE}/zuul/ansible"
touch "${ZUUL_ANSIBLE}/zuul/ansible/__init__.py"
touch "${ZUUL_ANSIBLE}/zuul/__init__.py"

if [ -z $1 ] ; then
    INVENTORY=$WORK_DIR/hosts.yaml
    cat >$INVENTORY <<EOF
all:
  hosts:
    controller:
      ansible_connection: local
    node1:
      ansible_connection: local
    node2:
      ansible_connection: local
node:
  hosts:
    node1: null
    node2: null
EOF
else
    INVENTORY=$(realpath $1)
fi

cat >$WORK_DIR/ansible.cfg <<EOF
[defaults]
inventory = $INVENTORY
gathering = smart
gather_subset = !all
fact_caching = jsonfile
fact_caching_connection = ~/.cache/facts
lookup_plugins = ${ZUUL_ANSIBLE}/zuul/ansible/lookup
callback_plugins = ${ZUUL_ANSIBLE}/zuul/ansible/callback:$ARA_DIR/plugins/callbacks
action_plugins = ${ZUUL_ANSIBLE}/zuul/ansible/actiongeneral:${ZUUL_ANSIBLE}/zuul/ansible/actiontrusted
module_utils = ${ZUUL_ANSIBLE}/zuul/ansible/module_utils
stdout_callback = zuul_stream
library = ${ZUUL_ANSIBLE}/zuul/ansible/library
retry_files_enabled = False
EOF

cd $WORK_DIR
python3 $ZUUL_DIR/zuul/ansible/logconfig.py
export ZUUL_JOB_LOG_CONFIG=$WORK_DIR/logging.json
export ARA_DIR=$WORK_DIR/.ara
export ARA_LOG_CONFIG=$ZUUL_JOB_LOG_CONFIG
export PYTHONPATH="${ZUUL_ANSIBLE}:${PYTHONPATH}"
export ZUUL_JOBDIR=$WORK_DIR
rm -rf $ARA_DIR

"${ANSIBLE_ROOT}/bin/ansible" all -m zuul_console

ANSIBLE="${ANSIBLE_ROOT}/bin/ansible-playbook"
"${ANSIBLE}" "${ZUUL_DIR}/playbooks/zuul-stream/fixtures/test-stream.yaml"
"${ANSIBLE}" "${ZUUL_DIR}/playbooks/zuul-stream/fixtures/test-stream-failure.yaml"
# ansible-playbook $ZUUL_DIR/playbooks/zuul-stream/functional.yaml
echo "Logs are in $WORK_DIR"
