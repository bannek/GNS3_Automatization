#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge man-db

sudo DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:remmina-ppa-team/remmina-next-daily
sudo DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:gns3/ppa  

sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

sudo DEBIAN_FRONTEND=noninteractive apt install net-tools -y

# GNS3   
sudo DEBIAN_FRONTEND=noninteractive apt install gns3-gui gns3-server -y

# Guacamole dependencies

sudo DEBIAN_FRONTEND=noninteractive apt install -y gcc vim curl wget g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev \
libtool-bin libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev build-essential \
libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev \
libssl-dev libvorbis-dev libwebp-dev

sudo DEBIAN_FRONTEND=noninteractive apt install freerdp2-dev freerdp2-x11 -y

sudo DEBIAN_FRONTEND=noninteractive apt install openjdk-11-jdk -y

sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat

wget https://downloads.apache.org/tomcat/tomcat-9/v9.0.56/bin/apache-tomcat-9.0.56.tar.gz

sudo mkdir /opt/tomcat
sudo tar -xzf apache-tomcat-9.0.56.tar.gz -C /opt/tomcat/
sudo mv /opt/tomcat/apache-tomcat-9.0.56 /opt/tomcat/tomcatapp

sudo chmod +x /opt/tomcat/tomcatapp/bin/*.sh

sudo chown -R tomcat: /opt/tomcat

sudo runuser -l root -c 'echo "
[Unit]
Description=Tomcat 9 servlet container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment=\"JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64\"
Environment=\"JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true\"

Environment=\"CATALINA_BASE=/opt/tomcat/tomcatapp\"
Environment=\"CATALINA_HOME=/opt/tomcat/tomcatapp\"
Environment=\"CATALINA_PID=/opt/tomcat/tomcatapp/temp/tomcat.pid\"
Environment=\"CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC\"

ExecStart=/opt/tomcat/tomcatapp/bin/startup.sh
ExecStop=/opt/tomcat/tomcatapp/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
" >> /etc/systemd/system/tomcat.service'

sudo systemctl daemon-reload

sudo systemctl enable --now tomcat

sudo ufw allow 8080/tcp

# Building Guacamole

# wget https://downloads.apache.org/guacamole/1.3.0/source/guacamole-server-1.3.0.tar.gz -P ~

# tar xzf ~/guacamole-server-1.3.0.tar.gz

# cd ~/guacamole-server-1.3.0

git clone git://github.com/apache/guacamole-server.git

cd guacamole-server/

autoreconf -fi

./configure --with-init-dir=/etc/init.d

make
sudo make install

sudo ldconfig

cd ..

sudo runuser -l root -c 'echo "[server]" >> /etc/guacamole/guacd.conf'
sudo runuser -l root -c 'echo "bind_host = 0.0.0.0" >> /etc/guacamole/guacd.conf'
sudo runuser -l root -c 'echo "bind_port = 4822" >> /etc/guacamole/guacd.conf'

sudo systemctl daemon-reload

sudo systemctl start guacd
sudo systemctl enable guacd

# Guacamole Web App

sudo mkdir /etc/guacamole
wget https://downloads.apache.org/guacamole/1.3.0/binary/guacamole-1.3.0.war -P ~
sudo mv ~/guacamole-1.3.0.war /etc/guacamole/guacamole.war

sudo ln -s /etc/guacamole/guacamole.war /opt/tomcat/tomcatapp/webapps

sudo runuser -l root -c 'echo "GUACAMOLE_HOME=/etc/guacamole" | tee -a /etc/default/tomcat'

sudo runuser -l root -c 'echo "guacd-hostname: localhost
guacd-port:    4822
user-mapping:    /etc/guacamole/user-mapping.xml
auth-provider:    net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider" >> /etc/guacamole/guacamole.properties'

sudo ln -s /etc/guacamole /opt/tomcat/tomcatapp/.guacamole

# echo "<user-mapping>

#     <!-- Per-user authentication and config information -->

#     <!-- A user using md5 to hash the password
#          guacadmin user and its md5 hashed password below is used to
#              login to Guacamole Web UI-->
#     <authorize username=\"$1\" password=\"$2\">
#         <protocol>rdp</protocol>
#         <param name=\"hostname\">192.168.1.90</param>
#         <param name=\"port\">3389</param>

#     </authorize>

# </user-mapping>
# " > ~/user-mapping.xml

echo "<user-mapping>

    <!-- Per-user authentication and config information -->

    <!-- A user using md5 to hash the password
         guacadmin user and its md5 hashed password below is used to 
             login to Guacamole Web UI-->
    <authorize 
            username=\"$1\"
            password=\"$2\">

        <connection name=\"Windows Server 2019\">
            <protocol>rdp</protocol>
            <param name=\"hostname\">192.168.0.100</param>
            <param name=\"port\">3389</param>
            <param name=\"username\">vagrant</param>
            <param name=\"ignore-cert\">true</param>
        </connection>

    </authorize>

</user-mapping>
" > ~/user-mapping.xml

sudo runuser -l root -c "mv /root/user-mapping.xml /etc/guacamole/"

sudo systemctl restart tomcat guacd

sudo ufw allow 4822/tcp

sudo DEBIAN_FRONTEND=noninteractive apt install xrdp -y
sudo adduser tomcat ssl-cert 
sudo adduser vagrant ssl-cert
sudo ufw allow 3389/tcp
sudo /etc/init.d/xrdp restart

sudo update-rc.d guacd defaults

echo "[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
" > ~/45-allow-colord.pkla

sudo runuser -l root -c "mv /root/45-allow-colord.pkla /etc/polkit-1/localauthority/50-local.d/"

sudo rm /var/crash/*

# GUI
sudo DEBIAN_FRONTEND=noninteractive apt install tasksel -y
sudo DEBIAN_FRONTEND=noninteractive tasksel install ubuntu-desktop
# systemctl set-default graphical.target

sudo reboot now
