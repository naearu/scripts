#!/bin/bash

echo "##################################################"

USERNAME=web

read -p "Enter the new username[default=$USERNAME]: " NEW_USERNAME
if [[ $NEW_USERNAME != "" ]]; then
	USERNAME=$NEW_USERNAME
fi


printf "\n\n## Update & Upgrade \n\n"
dnf -y upgrade && dnf clean all

dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm

dnf -y module reset php nodejs nginx
dnf -y module enable nodejs:20 php:remi-8.4 nginx:1.24
dnf -y module install nodejs:20/common php:remi-8.2

yum install -y php php-common php-fpm php-intl \
php-gd php-json php-curl php-mbstring php-xml php-bcmath \
php-zip php-soap php-redis php-imagick php-zip \
nginx npm vim wget tar composer


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

su $USERNAME -c "cd ~&&composer create-project laravel/laravel:^11 app"
su $USERNAME -c "cd ~/app&&npm install&&npm run build"
su $USERNAME -c "cd ~/app&&php artisan storage:link"

chown -R $USERNAME:$USERNAME /home/$USERNAME

service nginx restart
service php-fpm restart
