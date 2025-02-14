#!/bin/bash

echo "#v0115.8 ##################################################"

USERNAME=web

read -p "Enter the new username[default=$USERNAME]: " NEW_USERNAME
if [[ $NEW_USERNAME != "" ]]; then
	USERNAME=$NEW_USERNAME
fi


# Update system packages
printf "\nUpdating system packages...\n"
dnf -y upgrade
dnf install https://rpms.remirepo.net/enterprise/remi-release-9.rpm -y
dnf install epel-release -y
dnf makecache


# Install Apache
printf "\nInstalling Apache...\n"
dnf -y install httpd httpd-devel \
apr apr-util apr-devel apr-util-devel \
apr-util-openssl mod_proxy_html apr-util \
libnghttp2 mod_http2 mod_ssl httpd-tools

# mod_security


# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Install MySQL Server (MariaDB)
printf "\nInstalling MariaDB Server...\n"
dnf install mariadb-server -y


# Install PHP and extensions
printf "\nInstalling PHP and extensions...\n"
dnf -y module reset php
dnf -y module enable php:remi-8.4
dnf -y module install php:remi-8.4

yum install -y php php-common php-intl php-cli \
php-gd php-json php-curl php-mbstring php-xml php-bcmath \
php-zip php-soap php-redis php-imagick php-zip php-ldap \
php-pgsql php-mysql php-mysqlnd \
supervisor vim wget tar composer openssh-server git unzip



# Restart Apache to load PHP module
printf "\nRestarting Apache...\n"
systemctl restart httpd


# Configure firewall
printf "\nConfiguring firewall...\n"
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload


printf "\nConfiguring PHP...\n"
sed -i 's/\;date\.timezone\ \=/date\.timezone\ \=\ Asia\/Seoul/g' /etc/php.ini
sed -i 's/post\_max\_size\ \=\ 8M/post\_max\_size\ =\ 50M/g' /etc/php.ini
sed -i 's/upload\_max\_filesize\ \=\ 2M/upload\_max\_filesize\ \=\ 50M/g' /etc/php.ini
sed -i 's/memory\_limit\ \=\ 128M/memory\_limit\ \=\ 512M/g' /etc/php.ini
sed -i 's/expose\_php\ \=\ On/expose\_php\ \=\ Off/g' /etc/php.ini

sed -i "s/user\ \=\ apache/user\ \=\ $USERNAME/g" /etc/php-fpm.d/www.conf
sed -i "s/group\ \=\ apache/group\ \=\ $USERNAME/g" /etc/php-fpm.d/www.conf
sed -i "s/;listen\.mode\ \=\ 0660/listen\.mode\ \=\ 0666/g" /etc/php-fpm.d/www.conf


systemctl restart php-fpm

chmod 666 /run/php-fpm/www.sock


# create user
printf "\nCreating user $USERNAME\n"

echo -ne "\n\n" | adduser $USERNAME

chmod +x /home/$USERNAME
mkdir -p /home/$USERNAME/log/
mkdir -p /home/$USERNAME/ssl/
mkdir -p /home/$USERNAME/app/public
chown -R $USERNAME:$USERNAME /home/$USERNAME
chmod +x /home/$USERNAME

# add sudoers 
printf "\n\n$USERNAME  ALL=(ALL)  ALL\n\n" >> /etc/sudoers


# Create SSL certificates
printf "\nCreating SSL certificates...\n"

cd /home/$USERNAME/ssl/

openssl genrsa -out rootCA.key 2048
echo -ne "\n\n\n\n\n\n\n\n\n" | openssl req -new -key rootCA.key -out rootCA.csr
openssl x509 -req -in rootCA.csr -signkey rootCA.key -out rootCA.crt
openssl genrsa -out server.key 2048
echo -ne "\n\n\n\n\n\n\n\n\n" | openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out server.crt

cp -R ~/.ssh /home/$USERNAME/
chown -R $USERNAME:$USERNAME /home/$USERNAME/

printf "\nDeploy key --- \n"
su $USERNAME -c "echo -ne \"\n\n\n\n\n\n\n\n\n\" | ssh-keygen -t rsa"



# Create default index.php
printf "\nCreating default index.php...\n"
printf "<?php phpinfo(); ?>" > /home/$USERNAME/app/public/index.php

chown -R $USERNAME:$USERNAME /home/$USERNAME

# Configure Apache
printf "\nConfiguring Apache...\n"
wget https://raw.githubusercontent.com/naearu/scripts/main/apache/2.4.conf -O /etc/httpd/conf.d/vhost.conf

sed -i "s/\/home\/web\//\/home\/$USERNAME\//g" /etc/httpd/conf.d/vhost.conf

sed -i "s/User apache/User $USERNAME/g" /etc/httpd/conf/httpd.conf
sed -i "s/Group apache/Group $USERNAME/g" /etc/httpd/conf/httpd.conf

mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.bak


systemctl restart httpd


# Verify installations
printf "Verifying installations..."
apache_version=$(httpd -v | grep "Server version")
php_version=$(php -v | head -n 1)
mariadb_version=$(mysql --version)
host_ip=$(hostname -I)

printf "\nInstallation Summary:"
printf "\nApache Version: $apache_version\n"
printf "\nPHP Version: $php_version\n"
printf "\nMariaDB Version: $mariadb_version\n"
printf "\nhost IP: $host_ip\n"


# deploy key
printf "\n\nDeploy key --- \n\n"
cat /home/$USERNAME/.ssh/id_rsa.pub

printf "\n\nAPM stack installation completed!\n"
printf "You can place your PHP files in /home/$USERNAME/app/public and access them via your server's IP address.\n\n"

printf "\nPlease run \"mysql_secure_installation\" to set the root password and configure security settings.\n\n"

