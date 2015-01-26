BuildBotics
===========

[Buildbotics.com](http://buildbotics.com/) website

# Prerequisites
  - [C!](https://github.com/CauldronDevelopmentLLC/cbang)
  - [libre2](https://code.google.com/p/re2/)
  - [mariadb](https://mariadb.org/)

In Debian Linux, after installing C!, you can install the prerequsites as
follows:

First add the file ```/etc/apt/sources.list.d/mariadb.list``` with these
contents:

    deb http://mirrors.syringanetworks.net/mariadb/repo/10.0/debian sid main
    deb-src http://mirrors.syringanetworks.net/mariadb/repo/10.0/debian sid main

Install the MariaDB repo keys:

    gpg --keyserver keys.gnupg.net --recv-keys CBCB082A1BB943DB
    gpg -a --export CBCB082A1BB943DB | apt-key add -

Then install the packages like this:

    sudo apt-get update
    sudo apt-get install libre2-dev libmariadbclient-dev mariadb-server-10.0

# Build

    export CBANG_HOME=/path/to/cbang
    scons

