#!/usr/bin/env python
# Copyright 2013 OpenStack Foundation
# Copyright 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen
import json
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('url', help='The URL of the running Zuul instance')
parser.add_argument('tenant', help='The Zuul tenant', nargs='?')
parser.add_argument('pipeline', help='The name of the Zuul pipeline',
                    nargs='?')
options = parser.parse_args()

# Check if tenant is white label
info = json.loads(urlopen('%s/api/info' % options.url).read())
api_tenant = info.get('info', {}).get('tenant')
tenants = []
if api_tenant:
    if api_tenant == options.tenant:
        tenants.append(None)
    else:
        print("Error: %s doesn't match tenant %s (!= %s)" % (
            options.url, options.tenant, api_tenant))
        exit(1)
else:
    tenants_url = '%s/api/tenants' % options.url
    data = json.loads(urlopen(tenants_url).read())
    for tenant in data:
        tenants.append(tenant['name'])

for tenant in tenants:
    if tenant is None:
        status_url = '%s/api/status' % options.url
    else:
        status_url = '%s/api/tenant/%s/status' % (options.url, tenant)

    data = json.loads(urlopen(status_url).read())

    for pipeline in data['pipelines']:
        if options.pipeline and pipeline['name'] != options.pipeline:
            continue
        for queue in pipeline['change_queues']:
            for head in queue['heads']:
                for change in head:
                    if not change['live']:
                        continue

                    if change['id'] and ',' in change['id']:
                        # change triggered
                        cid, cps = change['id'].split(',')
                        print("zuul enqueue"
                              " --tenant %s"
                              " --pipeline %s"
                              " --project %s"
                              " --change %s,%s" % (tenant, pipeline['name'],
                                                   change['project_canonical'],
                                                   cid, cps))
                    else:
                        # ref triggered
                        cmd = 'zuul enqueue-ref' \
                              ' --tenant %s' \
                              ' --pipeline %s' \
                              ' --project %s' \
                              ' --ref %s' % (tenant, pipeline['name'],
                                             change['project_canonical'],
                                             change['ref'])
                        if change['id']:
                            cmd += ' --newrev %s' % change['id']
                        print(cmd)
