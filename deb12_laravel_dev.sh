#!/bin/bash

echo "##################################################"

USERNAME=web

read -p "Enter the new username[default=$USERNAME]: " NEW_USERNAME
if [[ $NEW_USERNAME != "" ]]; then
	USERNAME=$NEW_USERNAME
fi




printf "\n\n## Update & Upgrade \n\n"
apt update && apt -y upgrade

printf "\n\n## Installation of required items\n\n"
apt install -y nginx php8.2-fpm php8.2-gd php-json php8.2-mysql php8.2-curl php8.2-mbstring php8.2-intl php-imagick php8.2-xml php8.2-zip php8.2-redis php8.2-bcmath php8.2-soap composer nodejs npm sudo vim


echo -ne "\n\n\n\n\n\n\n\n\n" | adduser $USERNAME


sudo usermod -aG sudo $USERNAME

printf "\n\n## php-fprm \n\n"
cd /etc/php/8.2/fpm/pool.d/
sed -i "s/\;slowlog\ \=\ log\/\$pool\.log\.slow/slowlog\ \=\ \/var\/log\/php82-fpm\/www-slow\.log/g" www.conf
sed -i 's/\;request\_slowlog\_timeout\ \=\ 0/request\_slowlog\_timeout\ \=\ 10s/g' www.conf
sed -i 's/\;request\_terminate\_timeout\ \=\ 0/request\_terminate\_timeout\ \=\ 1200/g' www.conf
sed -i 's/\;catch\_workers\_output\ \=\ yes/catch\_workers\_output = yes/g' www.conf
sed -i "s/user\ \=\ www-data/user\ \=\ $USERNAME/g" www.conf
sed -i "s/group\ \=\ www-data/group\ \=\ $USERNAME/g" www.conf

mkdir /var/log/php82-fpm
service php8.2-fpm start

printf "\n\n## php.ini \n\n"
cd /etc/php/8.2/fpm/
#sed -i 's/\;date\.timezone\ \=/date\.timezone\ \=\ Asia\/Seoul/g' php.ini
sed -i 's/post\_max\_size\ \=\ 8M/post\_max\_size\ =\ 50M/g' php.ini
sed -i 's/upload\_max\_filesize\ \=\ 2M/upload\_max\_filesize\ \=\ 50M/g' php.ini
sed -i 's/memory\_limit\ \=\ 128M/memory\_limit\ \=\ 512M/g' php.ini

printf "\n\n## nginx \n\n"
cd /etc/nginx/
sed -i "s/user\ www\-data\;/user\ $USERNAME\;/g" nginx.conf

rm /etc/nginx/sites-enabled/default
wget https://raw.githubusercontent.com/naearu/scripts/main/nginx/laravel.conf -O /etc/nginx/sites-enabled/laravel.conf

sed -i "s/\/web\//\/$USERNAME\//g" /etc/nginx/sites-enabled/laravel.conf


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

su $USERNAME -c "cd ~&&composer create-project laravel/laravel:^10 app"
su $USERNAME -c "cd ~/app&&npm install&&npm run build"
su $USERNAME -c "cd ~/app&&php artisan storage:link"

chown -R $USERNAME:$USERNAME /home/$USERNAME

service nginx restart
service php8.2-fpm restart


