#!/usr/bin/python3

# svcrun.py - using SSH, execute a batch of commands on multiple IBM SVC/Storwize storage systems
# 
# Python 3 and Paramiko (http://www.paramiko.org/) module are required
# Edit svcrun_conf.py to set targets, logins, passwords and all other parameters
#
# Usage:
#  ./svcrun.py
#
# 2017.09.14  v 1.0   Mikhail Zakharov <zmey20000@yahoo.com>

import sys
import datetime
import paramiko

# Configurable values are in svcrun_conf.py
import svcrun_conf


def ssh_exec(command, target, port=22):
    """Execute a command via SSH and read results"""

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(target[0], username=target[1], password=target[2], port=port)
    except:
        return 'Error: {user}@{target}: is inaccessible: {error}'.format(user=target[1], target=target[0],
                                                                         error=sys.exc_info()[1])

    stdin, stdout, stderr = client.exec_command(command)

    error = stderr.read()
    if error:
        error = error.decode('US-ASCII')
        client.close()
        return 'Error: {user}@{target}: "{command}" has failed: {error}'.format(target=target[0], user=target[1],
                                                                                command=command, error=error)

    data = stdout.read()
    client.close()

    try:
        data = data.decode('UTF-8')
    except UnicodeDecodeError:
        data = data.decode('US-ASCII')

    return data


def runcommand(target, command):
    dt = '{0:%Y-%m-%d-%H-%M-%S}'.format(datetime.datetime.now())

    print(dt, 'Run command: "{cmd}"'.format(cmd=command), file=sys.stderr)
    print(ssh_exec(command, target), file=open(dt + '_' + target[0] + '_' + command.split()[0] + '.out', 'a'))


for target in svcrun_conf.svc_targets:
    for command in svcrun_conf.svc_commands:
        runcommand(target, command)

print('Done', file=sys.stderr)
