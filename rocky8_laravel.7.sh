#!/bin/bash

echo "##################################################"

USERNAME=web

read -p "Enter the new username[default=$USERNAME]: " NEW_USERNAME
if [[ $NEW_USERNAME != "" ]]; then
	USERNAME=$NEW_USERNAME
fi


printf "\n\n## Update & Upgrade \n\n"
yum -y upgrade && yum clean all

printf "\n\n## Installation of required items\n\n"
dnf module -y reset nodejs
dnf module -y enable nodejs:12
dnf module -y install nodejs:12/common
yum install -y nginx php php-common php-fpm php-gd php-json \
php-curl php-mbstring php-intl  php-xml php-zip  php-bcmath \
php-soap npm vim php-devel php-pear make wget tar epel-release \
php-pgsql php-mysql openssh-server

# php-redis
wget https://pecl.php.net/get/redis-5.3.7.tgz
tar xvf redis-5.3.7.tgz
cd redis-5.3.7
phpize
./configure --enable-redis --with-php-config=/usr/bin/php-config
make && make install
echo "extension=redis" > /etc/php.d/redis.ini

rm redis-5.3.7.tgz
rm -rf redis-5.3.7

# composer
wget https://getcomposer.org/installer -O composer-installer.php
php composer-installer.php --filename=composer --install-dir=/usr/local/bin

# php-imagick
/usr/bin/crb enable
dnf makecache
dnf install -y ImageMagick ImageMagick-devel
echo -ne "\n\n" | pecl install imagick
echo "extension=imagick.so" > /etc/php.d/20-imagick.ini


echo -ne "\n\n" | adduser $USERNAME


printf "\n\n## php-fprm \n\n"

sed -i 's/\;request\_slowlog\_timeout\ \=\ 0/request\_slowlog\_timeout\ \=\ 10s/g' /etc/php-fpm.d/www.conf
sed -i 's/\;request\_terminate\_timeout\ \=\ 0/request\_terminate\_timeout\ \=\ 1200/g' /etc/php-fpm.d/www.conf
sed -i 's/\;catch\_workers\_output\ \=\ yes/catch\_workers\_output = yes/g' /etc/php-fpm.d/www.conf
sed -i "s/user\ \=\ apache/user\ \=\ $USERNAME/g" /etc/php-fpm.d/www.conf
sed -i "s/group\ \=\ apache/group\ \=\ $USERNAME/g" /etc/php-fpm.d/www.conf
sed -i "s/listen\.acl_users\ \=\ apache\,nginx/listen\.acl_users\ \=\ apache\,nginx\,$USERNAME/g" /etc/php-fpm.d/www.conf

mkdir /var/log/php-fpm
service php-fpm start

printf "\n\n## php.ini \n\n"
#sed -i 's/\;date\.timezone\ \=/date\.timezone\ \=\ Asia\/Seoul/g' php.ini
sed -i 's/post\_max\_size\ \=\ 8M/post\_max\_size\ =\ 50M/g' /etc/php.ini
sed -i 's/upload\_max\_filesize\ \=\ 2M/upload\_max\_filesize\ \=\ 50M/g' /etc/php.ini
sed -i 's/memory\_limit\ \=\ 128M/memory\_limit\ \=\ 512M/g' /etc/php.ini

printf "\n\n## nginx \n\n"
sed -i "s/user\ nginx\;/user\ $USERNAME\;/g" /etc/nginx/nginx.conf


wget https://raw.githubusercontent.com/naearu/scripts/main/nginx/laravel.conf -O /etc/nginx/conf.d/laravel.conf
sed -i "s/\/web\//\/$USERNAME\//g" /etc/nginx/conf.d/laravel.conf
sed -i "s/\/run\/php\/php8\.2\-fpm\.sock/\/run\/php\-fpm\/www\.sock/g" /etc/nginx/conf.d/laravel.conf


printf "\n\n## Dir Setting\n\n"

mkdir -p /home/$USERNAME/log/
mkdir -p /home/$USERNAME/ssl/

## OPENSSL key
printf "\n\n## Create SSL key\n\n"

cd /home/$USERNAME/ssl/

openssl genrsa -out rootCA.key 2048
echo -ne "\n\n\n\n\n\n\n\n\n" | openssl req -new -key rootCA.key -out rootCA.csr
openssl x509 -req -in rootCA.csr -signkey rootCA.key -out rootCA.crt
openssl genrsa -out server.key 2048
echo -ne "\n\n\n\n\n\n\n\n\n" | openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out server.crt

su $USERNAME -c "cd ~&&composer create-project laravel/laravel:^7 app"
su $USERNAME -c "cd ~/app&&npm install&&npm run prod"
su $USERNAME -c "cd ~/app&&php artisan storage:link"

chown -R $USERNAME:$USERNAME /home/$USERNAME

service nginx restart
service php-fpm restart


