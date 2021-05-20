#!/usr/bin/env python3

# Copyright 2020 BMW Group
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

import argparse
import os
import subprocess


def main():
    pos_args = {
        '--dir': 1,
        '--tmpfs': 1,
        '--ro-bind': 2,
        '--bind': 2,
        '--chdir': 1,
        '--uid': 1,
        '--gid': 1,
        '--file': 2,
        '--proc': 1,
        '--dev': 1,
    }
    bool_args = [
        '--unshare-all',
        '--unshare-user',
        '--unshare-user-try',
        '--unshare-ipc',
        '--unshare-pid',
        '--unshare-net',
        '--unshare-uts',
        '--unshare-cgroup',
        '--unshare-cgroup-try',
        '--share-net',
        '--die-with-parent',
    ]
    parser = argparse.ArgumentParser()
    for arg, nargs in pos_args.items():
        parser.add_argument(arg, nargs=nargs, action='append')
    for arg in bool_args:
        parser.add_argument(arg, action='store_true')
    parser.add_argument('args', metavar='args', nargs=argparse.REMAINDER,
                        help='Command')

    args = parser.parse_args()

    for fd, path in args.file:
        fd = int(fd)
        if path.startswith('/etc'):
            # Ignore write requests to /etc
            continue
        print('Writing file from %s to %s' % (fd, path))
        count = 0
        with open(path, 'wb') as output:
            data = os.read(fd, 32000)
            while data:
                count += len(data)
                output.write(data)
                data = os.read(fd, 32000)
        print('Wrote file (%s bytes)' % count)

    if args.chdir:
        os.chdir(args.chdir[0][0])
    result = subprocess.run(args.args, shell=False, check=False)
    exit(result.returncode)


if __name__ == '__main__':
    main()
