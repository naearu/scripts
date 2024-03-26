#!/bin/bash
set -e

cat <<EOSTART
#######################################################
#                  MINIO SERVER SETUP                 #
#######################################################
# DEFAULTS:                                           #
#           MINIO_USER=minio-user                     #
#           MINIO_STORAGE_DIR=/minio/data             #
#           MINIO_PORT=9000                           #
#           MINIO_CONSOLE_PORT=9001                   #
#                                                     #
#######################################################
EOSTART

MINIO_USER=minio-user
MINIO_STORAGE_DIR=/minio/data
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001

setup_minio(){

echo "Installing And Configuring The Minio Server, just getting things ready first."

apt-get update && apt-get upgrade -y
apt-get install -y wget

echo "Installing Minio server"

wget -O /usr/local/bin/minio https://dl.minio.io/server/minio/release/linux-amd64/minio
chmod +x /usr/local/bin/minio

wget -O /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x /usr/local/bin/mc


# create minio user
echo "Creating a Minio user"
useradd -r $MINIO_USER -s /sbin/nologin

mkdir -p $MINIO_STORAGE_DIR
mkdir -p /etc/minio

echo "setup ownership to ${MINIO_USER} user"
chown $MINIO_USER:$MINIO_USER /usr/local/bin/minio
chown $MINIO_USER:$MINIO_USER /etc/minio
chown $MINIO_USER:$MINIO_USER $MINIO_STORAGE_DIR

MINIO_SERVICE_CONFIG=$(cat <<EOF
MINIO_VOLUMES=$MINIO_STORAGE_DIR
MINIO_OPTS="-C /etc/minio --address :$MINIO_PORT --console-address :$MINIO_CONSOLE_PORT"

# MINIO_SITE_NAME=***
# MINIO_SITE_REGION=***
# MINIO_ROOT_USER=minioadmin
# MINIO_ROOT_PASSWORD=minioadmin
# MINIO_SERVER_URL=https://api.example.com
# MINIO_BROWSER_REDIRECT_URL=https://minio.example.com
EOF
)

echo -e "$MINIO_SERVICE_CONFIG" > /etc/default/minio
echo "Wrote Config To /etc/default/minio:"
cat  /etc/default/minio

echo "Installing the Minio systemd startup script"
wget https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
mv minio.service /etc/systemd/system
systemctl daemon-reload

echo "Enable Minio to start on boot:"

systemctl enable minio
systemctl start minio

# mc admin user add local dev minioadmin-dev
# mc admin user add local api minioadmin-api
# mc admin policy set local readwrite user=dev
# mc admin policy set local readwrite user=api




if systemctl status minio | grep -q active; then
cat <<EOSUCCESS
#######################################################
#         MINIO SERVER INSTALLED AND RUNNING          #
#######################################################
#                                                     #
#             HTTP://localhost:$MINIO_PORT            #
#             HTTP://localhost:$MINIO_CONSOLE_PORT    #
#                                                     #
#######################################################
EOSUCCESS
else
cat <<EOFAILED
#######################################################
#              MINIO SERVER SETUP FAILED              #
#######################################################
EOFAILED
fi
}

change_defaults(){
  echo ''
  read -r -p "Enter the Minio server user [DEFAULT=$MINIO_USER] followed by [ENTER]: " CUSTOM_MINIO_USER
  if [[ $CUSTOM_MINIO_USER != "" ]]; then
    MINIO_USER=$CUSTOM_MINIO_USER
    echo "MINIO_USER changed to $MINIO_USER"
  fi
  read -r -p "Enter the Minio server storage directory [DEFAULT=$MINIO_STORAGE_DIR] followed by [ENTER]: " CUSTOM_MINIO_STORAGE_DIR
  if [[ $CUSTOM_MINIO_STORAGE_DIR != "" ]]; then
    MINIO_STORAGE_DIR=$CUSTOM_MINIO_STORAGE_DIR
    echo "MINIO_STORAGE_DIR changed to $MINIO_STORAGE_DIR"
  fi
  read -r -p "Enter the Minio server port [DEFAULT=$MINIO_PORT] followed by [ENTER]: " CUSTOM_MINIO_PORT
  if [[ $CUSTOM_MINIO_PORT != "" ]]; then
    MINIO_PORT=$CUSTOM_MINIO_PORT
    echo "MINIO_PORT changed to $MINIO_PORT"
  fi
  read -r -p "Enter the Minio console port [DEFAULT=$MINIO_CONSOLE_PORT] followed by [ENTER]: " CUSTOM_MINIO_CONSOLE_PORT
  if [[ $CUSTOM_MINIO_CONSOLE_PORT != "" ]]; then
    MINIO_CONSOLE_PORT=$CUSTOM_MINIO_CONSOLE_PORT
    echo "MINIO_CONSOLE_PORT changed to $MINIO_CONSOLE_PORT"
  fi

  setup_minio
}

read -r -p "Do you want to change the setup defaults? [Y/N] followed by [ENTER]: " RESPONSE
case $RESPONSE in
      [yY]* ) change_defaults ;;
      [nN]* ) setup_minio ;;
      *)
        echo "Invalid option: '$RESPONSE'" >&2
        exit 1 ;;
esac