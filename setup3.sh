#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# WARNA
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# IP
IP=$(curl -s ifconfig.me)

# REPO
REPO="https://raw.githubusercontent.com/sshmax07/sshmax2/main/"

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  » AUTO INSTALL VPN SERVER (OPTIMIZED VERSION)"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# VALIDASI ROOT
if [ "$EUID" -ne 0 ]; then
  echo "Run as root!"
  exit 1
fi

# ==============================
# BASE PACKAGE
# ==============================
base_package() {
    apt update -y
    apt install -y \
    zip pwgen openssl netcat socat cron bash-completion figlet sudo \
    ntpdate debconf-utils speedtest-cli vnstat net-tools iptables \
    iptables-persistent netfilter-persistent curl wget jq \
    build-essential gcc g++ make cmake git screen xz-utils \
    apt-transport-https dnsutils chrony fail2ban dropbear nginx haproxy

    systemctl enable --now chrony
    ntpdate pool.ntp.org

    systemctl disable --now ufw 2>/dev/null || true
    systemctl disable --now firewalld 2>/dev/null || true

    apt autoremove -y
    apt clean
}

# ==============================
# FIREWALL (SAFE)
# ==============================
firewall_setup() {
    iptables -P INPUT ACCEPT
    iptables -F

    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # SSH
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT

    # WEB
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    # UDP ZIVPN
    iptables -A INPUT -p udp --dport 5667 -j ACCEPT
    iptables -A INPUT -p udp --dport 6000:19999 -j ACCEPT

    iptables-save > /etc/iptables.up.rules
    netfilter-persistent save
}

# ==============================
# XRAY
# ==============================
install_xray() {
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data

    wget -q -O /etc/xray/config.json "${REPO}config/config.json"
    systemctl enable --now xray
}

# ==============================
# NGINX + HAPROXY
# ==============================
install_web() {
    systemctl enable --now nginx
    systemctl enable --now haproxy
}

# ==============================
# SSH + DROPBEAR
# ==============================
install_ssh() {
    systemctl enable --now ssh
    systemctl enable --now dropbear
}

# ==============================
# WS ePRO
# ==============================
install_ws() {
    wget -q -O /usr/bin/ws "${REPO}files/ws"
    chmod +x /usr/bin/ws

    wget -q -O /etc/systemd/system/ws.service "${REPO}files/ws.service"

    systemctl daemon-reload
    systemctl enable --now ws
}

# ==============================
# UDP MINI (ZIVPN)
# ==============================
install_udp() {
    wget -q https://raw.githubusercontent.com/sshmax07/sshmax2/main/config/fv-tunnel
    chmod +x fv-tunnel
    ./fv-tunnel

    for i in 1 2 3; do
        systemctl enable --now udp-mini-$i
    done
}

# ==============================
# BADVPN
# ==============================
install_badvpn() {
    screen -dmS badvpn7100 badvpn-udpgw --listen-addr 127.0.0.1:7100
    screen -dmS badvpn7200 badvpn-udpgw --listen-addr 127.0.0.1:7200
    screen -dmS badvpn7300 badvpn-udpgw --listen-addr 127.0.0.1:7300
}

# ==============================
# ENABLE SERVICE FINAL
# ==============================
enable_services() {
    systemctl daemon-reload

    for svc in nginx xray haproxy cron netfilter-persistent; do
        systemctl enable --now $svc
    done
}

# ==============================
# AUTOREBOOT
# ==============================
setup_autoreboot() {
    echo "0 3 * * * root reboot" > /etc/cron.d/reboot
    systemctl restart cron
}

# ==============================
# MAIN INSTALL
# ==============================
echo "Installing..."
base_package
firewall_setup
install_web
install_xray
install_ssh
install_ws
install_udp
install_badvpn
enable_services
setup_autoreboot

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}INSTALL SUCCESS${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "Press ENTER to reboot..."
reboot
