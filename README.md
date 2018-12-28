Buildbotics
===========

[Buildbotics.com](http://buildbotics.com/) website

# Prerequisites
  - [C!](https://github.com/CauldronDevelopmentLLC/cbang)
  - [libre2](https://code.google.com/p/re2/)
  - [mariadb](https://mariadb.org/)

In Debian Linux, after installing C!, you can install the prerequsites as
follows:

    sudo apt-get update
    sudo apt-get install libmariadbclient-dev mariadb-server ssl-cert \
      python-mysql.connector

# Build

    export CBANG_HOME=/path/to/cbang
    scons

# Create the DB and user

    mysql -u root -p
    CREATE DATABASE buildbotics;
    CREATE USER 'buildbotics'@'localhost' IDENTIFIED BY '<password>';
    GRANT EXECUTE ON buildbotics.* TO 'buildbotics'@'localhost';
    exit
    ./src/sql/update_db.py
