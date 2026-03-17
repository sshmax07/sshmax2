#!/bin/bash

# ============================================
# AUTO SCRIPT TUNNELING - OPTIMIZED VERSION
# ============================================

Green="\e[92;1m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[36m"
FONT="\033[0m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
OK="${Green}  ✔${FONT}"
ERROR="${RED}[✗]${FONT}"
NC='\e[0m'

clear
export IP=$(curl -sS icanhazip.com)

# Banner
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  🔥 TUNNELING SCRIPT OPTIMIZED v3.0 🔥"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
sleep 2

# ============================================
# VALIDASI SISTEM
# ============================================

# Cek root
if [ "${EUID}" -ne 0 ]; then
    echo -e "${ERROR} Jalankan sebagai root!"
    exit 1
fi

# Cek arsitektur
if [[ $(uname -m) != "x86_64" ]]; then
    echo -e "${ERROR} Arsitektur tidak didukung (harus x86_64)"
    exit 1
fi

# Cek OS
OS=$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/PRETTY_NAME=//g' | sed 's/"//g')
if [[ ! $OS =~ "Ubuntu" ]] && [[ ! $OS =~ "Debian" ]]; then
    echo -e "${ERROR} OS tidak didukung! (Harus Ubuntu/Debian)"
    exit 1
fi
echo -e "${OK} OS: $OS"

# Cek IP
if [[ -z $IP ]]; then
    echo -e "${ERROR} IP tidak terdeteksi!"
    exit 1
fi
echo -e "${OK} IP: $IP"

echo ""
read -p "$(echo -e "Press ${YELLOW}[ Enter ]${NC} to continue...")"
clear

# ============================================
# FUNGSI UTILITY
# ============================================

print_status() {
    echo -e "${BLUE}[•]${FONT} $1"
}

print_success() {
    echo -e "${Green}[✓]${FONT} $1 berhasil"
    sleep 1
}

print_error() {
    echo -e "${RED}[✗]${FONT} $1 gagal!"
}

secs_to_human() {
    echo "Waktu instalasi: $((${1} / 3600)) jam $(((${1} / 60) % 60)) menit $((${1} % 60)) detik"
}

# ============================================
# PREPARASI DIREKTORI
# ============================================

prepare_directories() {
    print_status "Menyiapkan direktori..."
    
    mkdir -p /etc/xray
    mkdir -p /var/log/xray
    mkdir -p /var/lib/kyt
    mkdir -p /etc/vmess /etc/vless /etc/trojan /etc/shadowsocks /etc/ssh
    mkdir -p /usr/bin/xray
    mkdir -p /var/www/html
    mkdir -p /etc/kyt/limit/{vmess,vless,trojan,ssh}/ip
    mkdir -p /etc/limit/{vmess,vless,trojan}
    mkdir -p /etc/user-create
    mkdir -p /etc/bot
    
    chown www-data:www-data /var/log/xray
    chmod 755 /var/log/xray
    
    touch /var/log/xray/{access,error}.log
    touch /etc/xray/domain
    
    echo "$IP" > /etc/xray/ipvps
    
    print_success "Direktori"
}

# ============================================
# SETUP AWAL
# ============================================

first_setup() {
    print_status "Konfigurasi awal sistem..."
    
    # Timezone
    timedatectl set-timezone Asia/Jakarta
    
    # Disable IPv6
    cat >/etc/sysctl.d/99-disable-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p /etc/sysctl.d/99-disable-ipv6.conf >/dev/null 2>&1
    
    # iptables persistent
    echo iptables-persistent iptables-persistent/autosave_v6 boolean false | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    
    print_success "Konfigurasi awal"
}

# ============================================
# INSTALL PACKAGES
# ============================================

base_package() {
    print_status "Menginstall package dasar..."
    
    apt update -y
    apt upgrade -y
    apt dist-upgrade -y
    
    apt install -y \
        curl wget jq git \
        zip unzip tar gzip \
        openssl netcat socat \
        cron bash-completion \
        ntpdate debconf-utils \
        vnstat net-tools \
        iptables iptables-persistent netfilter-persistent \
        build-essential gcc g++ make cmake \
        apt-transport-https dnsutils chrony \
        pwgen figlet sudo \
        screen xz-utils lsof \
        fail2ban rclone msmtp-mta ca-certificates bsd-mailx \
        nginx dropbear haproxy
        
    # Install speedtest
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
    apt install -y speedtest-cli
    
    # NTP
    systemctl enable --now chrony
    ntpdate pool.ntp.org
    
    # Hapus mail server gak perlu
    apt-get remove --purge exim4 -y 2>/dev/null
    
    apt autoremove -y
    apt autoclean -y
    
    print_success "Package dasar"
}

# ============================================
# FIREWALL
# ============================================

firewall_setup() {
    print_status "Konfigurasi firewall..."
    
    # Flush rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    
    # Default policy
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # UDP Mini
    iptables -A INPUT -p udp --dport 5667 -j ACCEPT
    iptables -A INPUT -p udp --dport 6000:19999 -j ACCEPT
    iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667
    
    # SSH
    iptables -A INPUT -p tcp --dport 22 -m connlimit --connlimit-above 3 -j DROP
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Web ports
    for port in 80 443 8080 8443 8880 2052 2082 2086 2095; do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT
    done
    
    # Drop invalid
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    
    # SYN flood protection
    iptables -A INPUT -p tcp --syn -m limit --limit 2/s --limit-burst 10 -j ACCEPT
    
    # Save rules
    iptables-save > /etc/iptables.up.rules
    netfilter-persistent save
    netfilter-persistent reload
    
    print_success "Firewall"
}

# ============================================
# DOMAIN SETUP
# ============================================

setup_domain() {
    clear
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "     SETUP DOMAIN"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  [1] Domain sendiri"
    echo -e "  [2] Domain random (bawaan)"
    echo -e "  [3] Skip (pakai IP)"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "  Pilih [1-3]: " domain_choice
    
    case $domain_choice in
        1)
            read -p "  Masukkan domain: " domain_name
            echo "$domain_name" > /etc/xray/domain
            echo "$domain_name" > /root/domain
            echo -e "${OK} Domain: $domain_name"
            ;;
        2)
            print_status "Mendapatkan domain random..."
            # Gunakan API gratis (contoh: sslip.io atau nip.io)
            domain_name="$IP.sslip.io"
            echo "$domain_name" > /etc/xray/domain
            echo "$domain_name" > /root/domain
            echo -e "${OK} Domain: $domain_name"
            ;;
        *)
            echo "$IP" > /etc/xray/domain
            echo "$IP" > /root/domain
            echo -e "${OK} Menggunakan IP langsung"
            ;;
    esac
}

# ============================================
# SSL CERTIFICATE (Pakai Let's Encrypt Resmi)
# ============================================

setup_ssl() {
    print_status "Memasang SSL Certificate..."
    
    domain=$(cat /root/domain 2>/dev/null || echo "$IP")
    
    # Cek apakah domain valid (bukan IP)
    if [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${YELLOW}⚠️ Domain adalah IP, generate self-signed certificate...${NC}"
        
        # Generate self-signed certificate
        openssl req -x509 -newkey rsa:4096 -keyout /etc/xray/xray.key -out /etc/xray/xray.crt \
            -days 365 -nodes -subj "/CN=$domain"
    else
        # Install certbot
        apt install -y certbot
        
        # Stop nginx dulu
        systemctl stop nginx 2>/dev/null
        
        # Request certificate
        certbot certonly --standalone --preferred-challenges http \
            --non-interactive --agree-tos --register-unsafely-without-email \
            -d "$domain" --keep-until-expiring
        
        if [[ -f /etc/letsencrypt/live/$domain/fullchain.pem ]]; then
            cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/xray/xray.crt
            cp /etc/letsencrypt/live/$domain/privkey.pem /etc/xray/xray.key
            echo -e "${OK} SSL Let's Encrypt berhasil"
        else
            # Fallback ke self-signed
            openssl req -x509 -newkey rsa:4096 -keyout /etc/xray/xray.key -out /etc/xray/xray.crt \
                -days 365 -nodes -subj "/CN=$domain"
            echo -e "${YELLOW}⚠️ Fallback ke self-signed certificate${NC}"
        fi
        
        # Start nginx lagi
        systemctl start nginx 2>/dev/null
    fi
    
    chmod 644 /etc/xray/xray.{crt,key}
    print_success "SSL Certificate"
}

# ============================================
# INSTALL XRAY CORE (Versi Terbaru)
# ============================================

install_xray() {
    print_status "Memasang Xray Core..."
    
    # Install Xray terbaru
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    # Download config
    wget -O /etc/xray/config.json "https://raw.githubusercontent.com/sshmax07/sshmax2/main/config/config.json" 2>/dev/null
    
    # Set domain di config
    domain=$(cat /etc/xray/domain)
    sed -i "s/xxx/$domain/g" /etc/xray/config.json 2>/dev/null
    
    # Create service
    cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray
    
    print_success "Xray Core"
}

# ============================================
# INSTALL UDP MINI (Anti-DPI)
# ============================================

install_udp() {
    print_status "Memasang UDP Mini (Anti-DPI)..."
    
    mkdir -p /usr/local/kyt
    
    # Download UDP Mini
    wget -q -O /usr/local/kyt/udp-mini "https://raw.githubusercontent.com/sshmax07/sshmax2/main/files/udp-mini"
    chmod +x /usr/local/kyt/udp-mini
    
    # Create services
    for i in 1 2 3; do
        port=$((5666 + i))
        cat >/etc/systemd/system/udp-mini-$i.service <<EOF
[Unit]
Description=UDP Mini $i
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/kyt/udp-mini -p $port
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable udp-mini-$i
        systemctl start udp-mini-$i
    done
    
    print_success "UDP Mini"
}

# ============================================
# INSTALL SSH SERVICES
# ============================================

install_ssh() {
    print_status "Mengkonfigurasi SSH..."
    
    # SSH Config
    wget -q -O /etc/ssh/sshd_config "https://raw.githubusercontent.com/sshmax07/sshmax2/main/files/sshd"
    chmod 600 /etc/ssh/sshd_config
    
    # Password authentication
    wget -q -O /etc/pam.d/common-password "https://raw.githubusercontent.com/sshmax07/sshmax2/main/files/password"
    chmod 644 /etc/pam.d/common-password
    
    systemctl restart ssh
    print_success "SSH"
}

install_dropbear() {
    print_status "Memasang Dropbear..."
    
    apt install -y dropbear
    
    wget -q -O /etc/default/dropbear "https://raw.githubusercontent.com/sshmax07/sshmax2/main/config/dropbear.conf"
    
    systemctl restart dropbear
    print_success "Dropbear"
}

# ============================================
# INSTALL WEBSOCKET
# ============================================

install_websocket() {
    print_status "Memasang WebSocket Proxy..."
    
    wget -q -O /usr/bin/ws "https://raw.githubusercontent.com/sshmax07/sshmax2/main/files/ws"
    wget -q -O /usr/bin/tun.conf "https://raw.githubusercontent.com/sshmax07/sshmax2/main/config/tun.conf"
    
    chmod +x /usr/bin/ws
    chmod 644 /usr/bin/tun.conf
    
    cat >/etc/systemd/system/ws.service <<EOF
[Unit]
Description=WebSocket Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ws
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable ws
    systemctl start ws
    
    print_success "WebSocket"
}

# ============================================
# INSTALL MENU SYSTEM
# ============================================

install_menu() {
    print_status "Memasang Menu System..."
    
    # Download menu
    wget -q -O /tmp/menu.zip "https://raw.githubusercontent.com/sshmax07/sshmax2/main/menu/menu.zip"
    unzip -q /tmp/menu.zip -d /tmp/menu/
    
    # Install ke /usr/local/sbin
    for file in /tmp/menu/menu/*; do
        chmod +x "$file"
        cp "$file" /usr/local/sbin/
    done
    
    # Bersihkan
    rm -rf /tmp/menu /tmp/menu.zip
    
    # Profile
    cat >/root/.profile <<EOF
# ~/.profile
if [ "\$BASH" ]; then
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
fi
mesg n || true
menu
EOF

    print_success "Menu System"
}

# ============================================
# SETUP CRON JOBS
# ============================================

setup_cron() {
    print_status "Memasang Cron Jobs..."
    
    # Backup otomatis jam 3 pagi
    echo "0 3 * * * root /usr/local/sbin/autobackup > /dev/null 2>&1" >> /etc/crontab
    
    # Restart Xray tiap hari (cegah memory leak)
    echo "0 5 * * * root systemctl restart xray" >> /etc/crontab
    
    # Clear log tiap 6 jam
    echo "0 */6 * * * root truncate -s 0 /var/log/xray/access.log" >> /etc/crontab
    echo "30 */6 * * * root truncate -s 0 /var/log/nginx/access.log" >> /etc/crontab
    
    # Hapus expired users
    echo "0 0 * * * root /usr/local/sbin/xp" >> /etc/crontab
    
    # Reboot tiap minggu (minggu jam 4 pagi)
    echo "0 4 * * 0 root /sbin/reboot" >> /etc/crontab
    
    systemctl restart cron
    print_success "Cron Jobs"
}

# ============================================
# CLEANUP
# ============================================

cleanup() {
    print_status "Membersihkan file temporary..."
    
    apt autoremove -y
    apt autoclean -y
    
    rm -f /root/*.sh /root/*.zip /root/*.deb /root/*.tar.gz
    rm -rf /tmp/*
    
    history -c
    echo "unset HISTFILE" >> /etc/profile
    
    print_success "Cleanup"
}

# ============================================
# MAIN INSTALLATION
# ============================================

main() {
    start=$(date +%s)
    
    prepare_directories
    first_setup
    base_package
    firewall_setup
    setup_domain
    setup_ssl
    install_xray
    install_udp
    install_ssh
    install_dropbear
    install_websocket
    install_menu
    setup_cron
    cleanup
    
    # Info akhir
    clear
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "           INSTALASI SELESAI! 🎉"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  IP VPS    : $IP"
    echo -e "  Domain    : $(cat /etc/xray/domain)"
    echo -e "  Total waktu: $(secs_to_human $(($(date +%s) - $start)))"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Jalankan: ${YELLOW}menu${NC} untuk melihat menu"
    echo -e "  Backup   : ${YELLOW}autobackup${NC} untuk setup backup otomatis"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "Press [Enter] to reboot..."
    reboot
}

# ============================================
# EKSEKUSI
# ============================================

main
