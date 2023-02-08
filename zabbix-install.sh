#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8
#=======================================================================================================#
# This script for install docker & zabbix          														#
# 												   														#
# 												   														#
# Installed software version:						   													#
# docker-buildx-plugin.x86_64     	0.10.2-1.el7   														#
# docker-ce.x86_64                	3:23.0.0-1.el7 														#
# docker-ce-cli.x86_64            	1:23.0.0-1.el7 														#
# docker-ce-rootless-extras.x86_64 	23.0.0-1.el7   														#
# docker-compose-plugin.x86_64     	2.15.1-3.el7   														#
# docker-scan-plugin.x86_64       	0.23.0-3.el7   														#
# 						   																				#
# 						   																				#
# Other information: 						   															#
# 						   																				#
# Directory:						   																	#
# /docker			   																					#
# /docker/zabbix			   																			#
# /docker/zabbix/db  																					#
# /docker/zabbix/fonts 																					#
# /docker/zabbix/alertscripts  																			#
#=======================================================================================================#

if [ $(whoami) != "root" ];then
	echo "Required root privileges"
	exit 1;
fi

IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v '^127\.|^255\.|^0\.' | head -n 1 )
PORT=8080
MYSQL_PASSWORD=ZkD58eV0CwBx
MYSQL_ROOT_PASSWORD=rY2RWcH7SILt

# Remove older version docker or docker-engine.
sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

# Set up the repository
sudo yum install -y yum-utils ntp chrony net-tools && sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install docker docker-compose
sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start docker and Enable start up
sudo systemctl start docker && sudo systemctl enable docker

# Set timezone to Asia/Manila
sudo timedatectl set-timezone Asia/Manila

# Enable NTP time synchronization
sudo timedatectl set-ntp true

# Start and enable chronyd service
sudo systemctl enable --now chronyd

# Verify if the service is started
sudo systemctl status chronyd

# Verify synchronisation state
sudo ntpstat

# Check Chrony Source Statistics
sudo chronyc sourcestats -v

# Create directory for docker
sudo mkdir /docker

# Create directory for zabbix
sudo mkdir /docker/zabbix

# Create directory for db
sudo mkdir /docker/zabbix/db

# Create directory for fonts
sudo mkdir /docker/zabbix/fonts

# Create directory for alertscripts
sudo mkdir /docker/zabbix/alertscripts

# Download Font & save to /docker/zabbix/fonts/DejaVuSans.ttf
sudo wget https://raw.githubusercontent.com/roythia/docker-zabbix/main/DejaVuSans.ttf -O /docker/zabbix/fonts/DejaVuSans.ttf

cat <<"EOF" | sudo tee /docker/zabbix/docker-compose.yml > /dev/null
version: '3'

services:
  zabbix-web-nginx-mysql:
    image: zabbix/zabbix-web-nginx-mysql:centos-5.2-latest
    restart: always
    environment:
      - DB_SERVER_HOST=zabbix-mysql
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - ZBX_SERVER_HOST=zabbix-server-mysql
    ports:
      - ${PORT}:8080
    volumes:
      - /etc/localtime:/etc/localtime
      - /docker/zabbix/fonts/DejaVuSans.ttf:/usr/share/zabbix/assets/fonts/DejaVuSans.ttf
    networks:
      - zbx_net
    depends_on:
      - zabbix-server-mysql
      - zabbix-mysql
  zabbix-mysql:
    image: mysql:8.0.23
    restart: always
    ports:
      - 3306:3306
    environment:
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    command:
      - mysqld
      - --default-authentication-plugin=mysql_native_password
      - --character-set-server=utf8
      - --collation-server=utf8_bin
    volumes:
      - /etc/localtime:/etc/localtime
      - /docker/zabbix/db:/var/lib/mysql
    networks:
      - zbx_net
  zabbix-java-gateway:
    image: zabbix/zabbix-java-gateway:centos-5.2-latest
    restart: always
    volumes:
      - /etc/localtime:/etc/localtime
    networks:
      - zbx_net
  zabbix-server-mysql:
    image: zabbix/zabbix-server-mysql:centos-5.2-latest
    restart: always
    volumes:
      - zabbix-server-vol:/etc/zabbix
      - /docker/zabbix/alertscripts:/usr/lib/zabbix/alertscripts
      - /etc/localtime:/etc/localtime
    ports:
      - 10051:10051
    environment:
      - DB_SERVER_HOST=zabbix-mysql
      - MYSQL_DATABASE=zabbix
      - MYSQL_USER=zabbix
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - ZBX_JAVAGATEWAY=zabbix-java-gateway
      - ZBX_JAVAGATEWAY_ENABLE=true
      - ZBX_JAVAGATEWAYPORT=10052
    depends_on:
      - zabbix-mysql
    networks:
      - zbx_net
  zabbix-agent:
    image: zabbix/zabbix-agent:centos-5.2-latest
    restart: always
    ports:
      - 10050:10050
    environment:
      - ZBX_HOSTNAME=Zabbix server
      - ZBX_SERVER_HOST=zabbix-server-mysql
      - ZBX_SERVER_PORT=10051
    networks:
      - zbx_net

networks:
  zbx_net:
    driver: bridge

volumes:
  zabbix-server-vol:
EOF

# go to /docker/zabbix & start docker-composer
cd /docker/zabbix && docker-compose up -d

echo "Check status: docker-compose ps"
echo "";
echo "Show logs: docker-compose logs"
echo "";
echo "Show Process: docker-compose top"
echo "";
echo "";
echo "";
echo "Stop: docker-compose start"
echo "";
echo "Stop: docker-compose stop"
echo "";
echo "Delete: docker-compose down"
echo "";
echo "Build: docker-compose up -d"
echo ""
echo ""
echo ""
echo "Zabbix install completed!"
echo "URL: http://${IP}:${PORT}"
echo "Username: Admin"
echo "Password: zabbix"