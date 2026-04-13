#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

Green="\e[92;1m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[36m"
FONT="\033[0m"
OK="${Green}  »${FONT}"
ERROR="${RED}[ERROR]${FONT}"
NC='\e[0m'

clear
export IP=$(curl -s ifconfig.me)

REPO="https://raw.githubusercontent.com/sshmax07/sshmax2/main/"

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  » This Will Quick Setup VPN Server On Your Server"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

sleep 1

# ==============================
# VALIDASI
# ==============================
if [[ $(uname -m) != "x86_64" ]]; then
    echo -e "${ERROR} Architecture Not Supported"
    exit 1
fi

if ! grep -Eq "ubuntu|debian" /etc/os-release; then
    echo -e "${ERROR} OS Not Supported"
    exit 1
fi

echo -e "${OK} IP: $IP"

read -p "Press Enter to start..."

# ==============================
# XRAY DIR
# ==============================
mkdir -p /etc/xray /var/log/xray /var/lib/kyt
touch /etc/xray/domain
touch /var/log/xray/access.log /var/log/xray/error.log

# ==============================
# BASE PACKAGE (RINGAN)
# ==============================
apt update -y
apt install -y zip unzip curl wget cron nginx haproxy \
iptables iptables-persistent netfilter-persistent \
fail2ban dropbear vnstat sudo socat jq dnsutils \
build-essential git screen xz-utils chrony

systemctl enable --now chrony
systemctl disable --now ufw 2>/dev/null || true

# ==============================
# DOMAIN
# ==============================
echo "1. Domain Sendiri"
echo "2. Auto Domain"
read -p "Pilih: " host

if [[ $host == "1" ]]; then
read -p "Domain: " domain
echo "$domain" > /etc/xray/domain
echo "$domain" > /root/domain
else
wget ${REPO}files/cf.sh -O cf.sh
chmod +x cf.sh && ./cf.sh
rm -f cf.sh
fi

# ==============================
# FIREWALL
# ==============================
iptables -P INPUT ACCEPT
iptables -F

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

iptables -A INPUT -p udp --dport 5667 -j ACCEPT
iptables -A INPUT -p udp --dport 6000:19999 -j ACCEPT

iptables-save > /etc/iptables.up.rules
netfilter-persistent save

# ==============================
# XRAY FIX
# ==============================
mkdir -p /etc/xray

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data

wget -O /etc/xray/config.json "${REPO}config/config.json"

systemctl enable --now xray

# ==============================
# SSH & DROPBEAR
# ==============================
systemctl enable --now ssh
systemctl enable --now dropbear

# ==============================
# WS ePRO FIX
# ==============================
wget -O /usr/bin/ws "${REPO}files/ws"
chmod +x /usr/bin/ws

wget -O /etc/systemd/system/ws.service "${REPO}files/ws.service"

systemctl daemon-reload
systemctl enable --now ws

# ==============================
# UDP MINI FIX
# ==============================
systemctl stop udp-mini-1 2>/dev/null || true
systemctl stop udp-mini-2 2>/dev/null || true
systemctl stop udp-mini-3 2>/dev/null || true
pkill -f udp-mini 2>/dev/null || true

mkdir -p /usr/local/kyt
rm -f /usr/local/kyt/udp-mini

wget -O /usr/local/kyt/udp-mini "${REPO}files/udp-mini"
chmod +x /usr/local/kyt/udp-mini

wget -O /etc/systemd/system/udp-mini-1.service "${REPO}files/udp-mini-1.service"
wget -O /etc/systemd/system/udp-mini-2.service "${REPO}files/udp-mini-2.service"
wget -O /etc/systemd/system/udp-mini-3.service "${REPO}files/udp-mini-3.service"

systemctl daemon-reload
systemctl enable --now udp-mini-1
systemctl enable --now udp-mini-2
systemctl enable --now udp-mini-3

# ==============================
# BADVPN
# ==============================
screen -dmS badvpn7100 badvpn-udpgw --listen-addr 127.0.0.1:7100
screen -dmS badvpn7200 badvpn-udpgw --listen-addr 127.0.0.1:7200
screen -dmS badvpn7300 badvpn-udpgw --listen-addr 127.0.0.1:7300

# ==============================
# MENU
# ==============================
wget ${REPO}menu/menu.zip
unzip menu.zip
chmod +x menu/*
mv menu/* /usr/local/sbin
rm -rf menu menu.zip

cat >/root/.profile <<EOF
if [ "\$BASH" ]; then
. ~/.bashrc
fi
menu
EOF

# ==============================
# AUTOREBOOT
# ==============================
echo "0 3 * * * root reboot" > /etc/cron.d/reboot
systemctl restart cron

# ==============================
# FINAL RESTART SERVICE
# ==============================
systemctl restart nginx
systemctl restart ssh
systemctl restart dropbear
systemctl restart ws
systemctl restart xray
systemctl restart haproxy
systemctl restart cron

echo -e "${Green}INSTALL SUCCESS${NC}"

read -p "Reboot sekarang? (y/n): " rb
[ "$rb" = "y" ] && reboot
