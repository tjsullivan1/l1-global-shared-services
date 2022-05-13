#!/bin/bash

touch /tmp/test

#Run updates
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install build-essential -y
sudo apt-get install -y mysql-server 
sudo apt-get install -y pwgen

sudo systemctl start mysql.service
sudo sed -i s/bind-address/\#bind-address/ /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql.service

PASS=`pwgen -s 20 1`

echo $PASS | tee ~/mysql.txt >/dev/null

mysql -uroot <<MYSQL_SCRIPT
CREATE USER 'wp'@'localhost' IDENTIFIED BY '$PASS';
GRANT ALL ON *.* to wp@'%' IDENTIFIED BY '$PASS';
FLUSH PRIVILEGES;

create database todos;

use todos;

create table todos (
    id INT NOT NULL AUTO_INCREMENT,
    task VARCHAR(256),
    PRIMARY KEY (id)
    );

MYSQL_SCRIPT