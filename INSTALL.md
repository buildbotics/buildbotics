How to Setup a Buildbotics Server
=================================

Intall Riak DB
--------------

    curl http://apt.basho.com/gpg/basho.apt.key | sudo apt-key add -
    sudo bash -c "echo deb http://apt.basho.com wheezy main \
      > /etc/apt/sources.list.d/basho.list"
    sudo apt-get update
    sudo apt-get install riak

Edit Riak Config
----------------

Edit /etc/riak/app.config

Change storage backend:

    {storage_backend, riak_kv_eleveldb_backend},


Enable search:

    {riak_search, [{enabled, true}]},


Increase default ulimit
-----------------------

    sudo vi /etc/security/limits.conf

Add:

    riak soft nofile 4096
    riak hard nofile 65536

Run:
    ulimit -n 65536

Start Riak
----------

    sudo service riak start


Install Nginx
-------------

    sudo apt-get install nginx


Configure Nginx
---------------

    sudo rm /etc/nginx/sites-enabled/default
    sudo touch /etc/nginx/sites-available/buildbotics.com
    sudo ln -s /etc/nginx/sites-{available,enabled}/buildbotics.com
    sudo vi /etc/nginx/sites-available/buildbotics.com

Add the following:

    upstream node_js {
      server 127.0.0.1:3000;
    }

    server {
      listen buildbotics.com;
      server_name buildbotics.com buildbotics.org;
      access_log /var/log/nginx/buildbotics.log;
      error_page 404 =200 /;

      location / {
        root /var/www/buildbotics.com;
      }

      location /api {
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_set_header X-NginX-Proxy true;

        proxy_pass http://node_js;
        proxy_redirect off;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      }
    }

Start Nginx
-----------

    sudo service nginx restart

Add server user
---------------

    sudo useradd server

Checkout source
---------------

    sudo apt-get install git
    sudo su server
    cd ~
    git clone https://github.com/buildbotics/buildbotics.git


Edit configuration
------------------

    cd buildbotics
    vi config.js

Install dependencies
--------------------

     sudo apt-get install npm
     npm install

Install static site
-------------------

     sudo mkdir -p /var/www
     sudo ln -s ~server/buildbotics/static /var/www/buildbotics.com
     cd ~server/buildbotics/
     make

Start node.js
-------------

     cd ~server/buildbotics
     sudo chmown -R server:server .
     sudo -u server forever start bin/www

Update the installed site
-------------------------

     cd ~server/buildbotics
     git pull
     make
     sudo chmown -R server:server .
     sudo -u server forever restart bin/www
