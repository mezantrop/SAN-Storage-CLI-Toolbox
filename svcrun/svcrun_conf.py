# Configuration file for svcsrun.py

# Default SVC/Storwize credentials
svc_username = 'username'
svc_password = 'password'

# SVC/Storwize systems to run commands on
svc_targets = {
    # 'Hostname/IP', 'Login', 'Password'),
    ('192.168.1.11', svc_username, svc_password),
    ('192.168.1.12', 'anotheruser', 'secret')
}

# Commands to run one by one on each SVC/Storwize system
svc_commands = [
    'lssystem -delim \,',
    'lsvdisk -nohdr -bytes -delim \,'
]
