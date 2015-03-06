#!/bin/bash

DB=buildbotics
AUTH=root

echo "select concat('drop trigger ', trigger_name, ';')
  from information_schema.triggers where trigger_schema = '$DB'" |
  mysql -u $AUTH $DB --disable-column-names -p |
  mysql -u $AUTH $DB -p
