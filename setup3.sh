#!/bin/bash

# ==========================================
# AUTO INSTALL TUNNELING SERVER V4 FIXED
# ==========================================

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[33m"
NC="\033[0m"

clear

IP=$(curl -sS ipv4.icanhazip.com)

if [ -z "$IP" ]; then
echo -e "${RED}IP VPS tidak terdeteksi${NC}"
exit
fi

echo -e "${GREEN}INSTALL TUNNELING SERVER${NC}"
sleep 2

# ==========================================
# PREPARE SYSTEM
# ==========================================

timedatectl set-timezone Asia/Jakarta

apt update -y
apt upgrade -y

apt install -y \
curl wget jq unzip \
iptables iptables-persistent \
net-tools cron socat \
nginx dropbear \
fail2ban vnstat

systemctl enable cron
systemctl start cron

# ==========================================
# DIRECTORY
# ==========================================

mkdir -p /etc/xray
mkdir -p /var/log/xray
mkdir -p /etc/vmess
mkdir -p /etc/vless
mkdir -p /etc/trojan

touch /var/log/xray/access.log
touch /var/log/xray/error.log

# ==========================================
# DOMAIN
# ==========================================

read -p "Masukkan domain / kosong pakai IP: " domain

if [ -z "$domain" ]; then
domain=$IP
fi

echo "$domain" > /etc/xray/domain

# ==========================================
# INSTALL XRAY
# ==========================================

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# CONFIG XRAY
cat > /etc/xray/config.json <<EOF
{
"log":{
"access":"/var/log/xray/access.log",
"error":"/var/log/xray/error.log",
"loglevel":"warning"
},
"inbounds":[
{
"port":443,
"protocol":"vmess",
"settings":{"clients":[]},
"streamSettings":{
"network":"ws",
"wsSettings":{"path":"/vmess"}
}
},
{
"port":80,
"protocol":"vmess",
"settings":{"clients":[]},
"streamSettings":{
"network":"ws",
"wsSettings":{"path":"/vmess"}
}
}
],
"outbounds":[
{
"protocol":"freedom",
"settings":{}
}
]
}
EOF

# ==========================================
# XRAY SERVICE FIX
# ==========================================

cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl start xray

# ==========================================
# FIREWALL FIX
# ==========================================

iptables -F
iptables -t nat -F

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# XRAY
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# DROPBEAR
iptables -A INPUT -p tcp --dport 109 -j ACCEPT
iptables -A INPUT -p tcp --dport 143 -j ACCEPT

# ==========================================
# IP FORWARD
# ==========================================

echo 1 > /proc/sys/net/ipv4/ip_forward

sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

sysctl -p

# ==========================================
# NAT INTERNET CLIENT
# ==========================================

IFACE=$(ip route get 1 | awk '{print $5;exit}')

iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE

netfilter-persistent save

# ==========================================
# DROPBEAR
# ==========================================

sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear

sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear

sed -i 's/DROPBEAR_EXTRA_ARGS=/DROPBEAR_EXTRA_ARGS="-p 143"/g' /etc/default/dropbear

systemctl restart dropbear

# ==========================================
# NGINX WEBSOCKET
# ==========================================

cat > /etc/nginx/conf.d/xray.conf <<EOF
server {
listen 80;

location /vmess {
proxy_redirect off;
proxy_pass http://127.0.0.1:10000;
proxy_http_version 1.1;
proxy_set_header Upgrade \$http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host \$host;
}
}
EOF

systemctl restart nginx

# ==========================================
# CRON
# ==========================================

echo "0 3 * * * root systemctl restart xray" >> /etc/crontab

systemctl restart cron

# ==========================================
# FINISH
# ==========================================

clear

echo "================================="
echo "INSTALL SELESAI"
echo "================================="

echo "IP VPS : $IP"
echo "Domain : $domain"

echo ""
echo "Port SSH      : 22"
echo "Port Dropbear : 109,143"
echo "Port VMESS    : 80,443"

echo ""
echo "Silakan reboot VPS"
