#!/usr/bin/env python


# Process options
from optparse import OptionParser

parser = OptionParser()
parser.add_option('-u', '--user', dest = 'user', help = 'DB user name',
                  default = 'root')
parser.add_option('', '--host', dest = 'host', help = 'DB host name',
                  default = 'localhost')
parser.add_option('-d', '--db', dest = 'db', help = 'DB name',
                  default = 'buildbotics')
parser.add_option('-r', '--reset', dest = 'reset', help = 'Reset DB',
                  default = False, action = 'store_true')


(options, args) = parser.parse_args()


# Ask pass
from getpass import getpass
db_pass = getpass('Password: ')


# Connect to DB
from mysql.connector import connect
from mysql.connector.errors import Error as MySQLError

db = connect(host = options.host, user = options.user, password = db_pass,
             database = options.db)
db.start_transaction()
cur = db.cursor()


# Get schema version
def version_to_str(v):
    return '.'.join(map(str, v))

def version_from_str(s):
    return map(int, s.split('.'))

version = None
try:
    cur.execute('SELECT value FROM config WHERE name = "version"')

    if cur.with_rows:
        version = version_from_str(cur.fetchone()[0])
        print 'DB version', version_to_str(version)

except: pass


# Get current path
import os
cwd = os.path.dirname(os.path.realpath(__file__))


# Read updates
from glob import glob
import re

updateRE = re.compile(r'^.*-(\d+\.\d+\.\d+)\.sql')
updates = []

for path in glob(cwd + '/update-*.sql'):
    m = updateRE.match(path)
    v = version_from_str(m.group(1))
    updates.append((v, path))

updates = sorted(updates)


# Latest version
if len(updates): latest = updates[-1]
else: latest = (0, 0, 0)


# Update
def exec_file(filename):
    sql = open(filename, 'r').read()

    for result in cur.execute(sql, multi = True):
        if result.with_rows:
            print result.fetchall()


if version is None or options.reset:
    # Init DB
    exec_file(cwd + '/schema.sql')
    exec_file(cwd + '/triggers.sql')
    exec_file(cwd + '/procedures.sql')

else:
    # Apply DB updates
    for v, path in updates:
        if version < v:
            print 'Applying update', version_to_str(v)
            exec_file(path)


# Update version
if version < latest or options.reset:
    cur.execute('REPLACE INTO config (name, value) VALUES ("version", "%s")' %
                version_to_str(latest))


# Commit
cur.close()
db.commit()
db.close()
