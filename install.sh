#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 yourdomain.com [burp-installation-path.sh]"
  exit 1
fi

DOMAIN=$1
BURP_INSTALLATOR="$2"

if [ ! -f /opt/BurpSuitePro/BurpSuitePro ]; then
  if [ -z "$BURP_INSTALLATOR" ]; then
    echo "Install Burp to /opt/BurpSuitePro and run script again or provide a path to burp installator"
    echo "Usage: $0 $DOMAIN burp-installation-path.sh"
    exit
  elif [ ! -f "$BURP_INSTALLATOR" ]; then
    echo "Burp installator ($BURP_INSTALLATOR) does not exist"
    exit
  fi
  bash "$BURP_INSTALLATOR" -q
  if [ ! -f /opt/BurpSuitePro/BurpSuitePro ]; then
    echo "Burp Suite Pro was not installed correctly. Please install it manually and run the script again"
    exit
  fi
fi

SRC_PATH="$(dirname \"$0\")"

# Get public IP in case not running on AWS or Digitalocean.
MYPUBLICIP=$(curl http://checkip.amazonaws.com/ -s)
MYPRIVATEIP=$(curl http://checkip.amazonaws.com/ -s)

# Get IPs if running on AWS.
curl http://169.254.169.254/latest -s --output /dev/null -f -m 1
if [ 0 -eq $? ]; then
  MYPRIVATEIP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 -s)
  MYPUBLICIP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4 -s)
fi;

# Get IPs if running on Digitalocean.
curl http://169.254.169.254/metadata/v1/id -s --output /dev/null -f -m1
if [ 0 -eq $? ]; then
  # Use Floating IP if the VM has it enabled.
  FLOATING=$(curl http://169.254.169.254/metadata/v1/floating_ip/ipv4/active -s)
  if [ "$FLOATING" == "true" ]; then
    MYPUBLICIP=$(curl http://169.254.169.254/metadata/v1/floating_ip/ipv4/ip_address -s)
    MYPRIVATEIP=$(curl http://169.254.169.254/metadata/v1/interfaces/public/0/anchor_ipv4/address -s)
  fi
  if [ "$FLOATING" == "false" ]; then
    MYPUBLICIP=$(curl http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address -s)
    MYPRIVATEIP=$MYPUBLICIP
  fi
fi;

apt update -y && apt install -y python3 python3-pip certbot && pip3 install dnslib
mkdir -p /usr/local/collaborator/
cp "$SRC_PATH/dnshook.sh" /usr/local/collaborator/
cp "$SRC_PATH/cleanup.sh" /usr/local/collaborator/
cp "$SRC_PATH/collaborator.config" /usr/local/collaborator/collaborator.config
sed -i "s/INT_IP/$MYPRIVATEIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/EXT_IP/$MYPUBLICIP/g" /usr/local/collaborator/collaborator.config
sed -i "s/BDOMAIN/$DOMAIN/g" /usr/local/collaborator/collaborator.config
cp "$SRC_PATH/burpcollaborator.service" /etc/systemd/system/
cp "$SRC_PATH/startcollab.sh" /usr/local/collaborator/
cp "$SRC_PATH/renewcert.sh" /etc/cron.daily/

cd /usr/local/collaborator/
chmod +x /usr/local/collaborator/*

systemctl disable systemd-resolved.service
systemctl stop systemd-resolved
rm -rf /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "options edns0" >> /etc/resolv.conf
echo "search eu-north-1.compute.internal" >> /etc/resolv.conf
grep $MYPRIVATEIP /etc/hosts -q || (echo $MYPRIVATEIP `hostname` >> /etc/hosts)

echo ""
echo "CTRL-C if you don't need to obtain certificates."
echo ""
read -p "Press enter to continue"

rm -rf /usr/local/collaborator/keys
certbot certonly --manual-auth-hook "/usr/local/collaborator/dnshook.sh $MYPRIVATEIP" --manual-cleanup-hook /usr/local/collaborator/cleanup.sh \
    -d "*.$DOMAIN, $DOMAIN"  \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --manual --agree-tos --no-eff-email --manual-public-ip-logging-ok --preferred-challenges dns-01

CERT_PATH=/etc/letsencrypt/live/$DOMAIN
ln -s $CERT_PATH /usr/local/collaborator/keys
