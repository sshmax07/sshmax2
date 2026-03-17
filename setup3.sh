#!/bin/bash

Green="\e[92;1m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[36m"
FONT="\033[0m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
OK="${Green}  »${FONT}"
ERROR="${RED}[ERROR]${FONT}"
GRAY="\e[1;30m"
NC='\e[0m'
red='\e[1;31m'
green='\e[0;32m'

clear
export IP=$(curl -sS icanhazip.com)
clear

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  » Optimized Tunnel Setup - By KYZZZ's Request"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
sleep 2

# --- Pengecekan Awal (Tetap sama kayak script lo) ---
if [[ $(uname -m) != "x86_64" ]]; then
    echo -e "${ERROR} Architektur Tidak Didukung ( ${YELLOW}$(uname -m)${NC} )"
    exit 1
fi

OS_SUPPORT=0
if grep -q -E "Ubuntu|Debian" /etc/os-release; then
    OS_SUPPORT=1
fi
if [ $OS_SUPPORT -eq 0 ]; then
    echo -e "${ERROR} OS Tidak Didukung ( ${YELLOW}$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)${NC} )"
    exit 1
fi

if [[ $IP == "" ]]; then
    echo -e "${ERROR} IP Address ( ${YELLOW}Tidak Terdeteksi${NC} )"
    exit 1
fi

echo ""
read -p "$( echo -e "Press ${GRAY}[ ${NC}${green}Enter${NC} ${GRAY}]${NC} Untuk Memulai Installasi") "
echo ""

if [ "${EUID}" -ne 0 ]; then
    echo -e "${ERROR} Jalankan script sebagai root"
    exit 1
fi

if [ "$(systemd-detect-virt)" == "openvz" ]; then
    echo -e "${ERROR} OpenVZ tidak didukung"
    exit 1
fi

MYIP=$(curl -sS ipv4.icanhazip.com)
echo -e "\e[32mloading...\e[0m"
clear

# REPO
REPO="https://raw.githubusercontent.com/sshmax07/sshmax2/main/"

start=$(date +%s)
secs_to_human() {
    echo "Waktu Installasi : $((${1} / 3600)) jam $(((${1} / 60) % 60)) menit $((${1} % 60)) detik"
}

print_ok() {
    echo -e "${OK} ${BLUE} $1 ${FONT}"
}

print_install() {
    echo -e "${green} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
    echo -e "${YELLOW} » $1 ${FONT}"
    echo -e "${green} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
    sleep 1
}

print_error() {
    echo -e "${ERROR} ${REDBG} $1 ${FONT}"
}

print_success() {
    if [[ 0 -eq $? ]]; then
        echo -e "${green} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
        echo -e "${Green} ✔ $1 berhasil dipasang"
        echo -e "${green} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
        sleep 2
    fi
}

# --- Setup Direktori (Tetap sama) ---
print_install "Membuat direktori Xray"
mkdir -p /etc/xray
curl -s ifconfig.me > /etc/xray/ipvps
touch /etc/xray/domain
mkdir -p /var/log/xray
chown www-data.www-data /var/log/xray
chmod +x /var/log/xray
touch /var/log/xray/access.log
touch /var/log/xray/error.log
mkdir -p /var/lib/kyt >/dev/null 2>&1

# --- Fungsi Setup Awal (Tetap sama) ---
function first_setup() {
    timedatectl set-timezone Asia/Jakarta
    print_install "Mematikan IPv6"
    cat >/etc/sysctl.d/99-disable-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    systemctl daemon-reload
    systemctl enable disable-ipv6.service &>/dev/null
    systemctl start disable-ipv6.service &>/dev/null
    print_success "IPv6 Dimatikan Permanen"

    echo iptables-persistent iptables-persistent/autosave_v6 boolean false | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections

    OS_ID=$(grep -w ID /etc/os-release | cut -d= -f2 | tr -d '"')
    if [[ "$OS_ID" == "ubuntu" ]]; then
        apt update -y
        apt install -y software-properties-common haproxy
    elif [[ "$OS_ID" == "debian" ]]; then
        curl -fsSL https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor -o /usr/share/keyrings/haproxy.debian.net.gpg
        echo "deb [signed-by=/usr/share/keyrings/haproxy.debian.net.gpg] http://haproxy.debian.net Bullseye-2.2 main" >/etc/apt/sources.list.d/haproxy.list
        apt update -y
        apt install -y haproxy=2.2.*
    fi
}

function nginx_install() {
    if [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/ID//g') == "ubuntu" ]]; then
        print_install "Setup nginx untuk Ubuntu"
        sudo apt-get install nginx -y
    else
        print_install "Setup nginx untuk Debian"
        apt -y install nginx
    fi
}

function base_package() {
    clear
    print_install "Menginstall Paket yang Dibutuhkan"
    apt update -y
    apt install -y zip pwgen openssl netcat socat cron bash-completion figlet sudo \
        ntpdate debconf-utils speedtest-cli vnstat net-tools iptables \
        iptables-persistent netfilter-persistent curl wget jq \
        build-essential gcc g++ make cmake git screen socat xz-utils \
        apt-transport-https dnsutils chrony
    apt upgrade -y
    apt dist-upgrade -y
    systemctl enable --now chrony
    ntpdate pool.ntp.org
    systemctl disable --now ufw 2>/dev/null
    systemctl disable --now firewalld 2>/dev/null
    apt-get remove --purge exim4 -y
    apt-get clean && apt-get autoremove -y
    print_success "Paket yang Dibutuhkan"
}

function security_hardening() {
    clear
    print_install "Security Hardening"
    sed -i 's/#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
    sed -i 's/#LoginGraceTime.*/LoginGraceTime 30/' /etc/ssh/sshd_config
    systemctl restart ssh
    print_success "Security Hardening"
}

# --- Firewall Setup dengan Improvement ---
function firewall_setup() {
    clear
    print_install "Firewall Hardening"
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p udp --dport 5667 -j ACCEPT
    iptables -A INPUT -p udp --dport 6000:19999 -j ACCEPT
    iptables -t nat -A PREROUTING -p udp --dport 6000:19999 -j DNAT --to-destination :5667
    iptables -A INPUT -p tcp --dport 22 -m connlimit --connlimit-above 3 -j DROP
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A INPUT -p tcp --syn -m limit --limit 2/s --limit-burst 10 -j ACCEPT

    # --- Improvement: Bersihin rule duplicate [citation:1] ---
    iptables-save | grep -v "comment" | awk '!x[$0]++' | iptables-restore
    # --------------------------------------------

    netfilter-persistent save
    netfilter-persistent reload
    print_success "Firewall Aktif"
}

# --- Input Domain (Tetap sama) ---
function pasang_domain() {
    echo -e ""
    clear
    echo -e "${green} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
    echo -e "${YELLOW}» SETUP DOMAIN CLOUDFLARE ${FONT}"
    echo -e "${green} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
    echo -e "  [1] Domain Pribadi"
    echo -e "  [2] Domain Bawaan (Cloudflare)"
    echo -e "${green} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ${FONT}"
    read -p "  Silahkan Pilih (1/2): " host
    echo ""
    if [[ $host == "1" ]]; then
        echo -e "   \e[1;32mMasukan Domain Anda ! $NC"
        read -p "   Subdomain: " host1
        echo $host1 > /etc/xray/domain
        echo $host1 > /root/domain
    else
        print_install "Memasang Domain Otomatis dari Cloudflare"
        # Ini adalah placeholder, script asli lo punya file cf.sh
        # Gue asumsikan file cf.sh di REPO lo akan mengisi /etc/xray/domain
        wget -O /root/cf.sh ${REPO}files/cf.sh && chmod +x /root/cf.sh && /root/cf.sh
        rm -f /root/cf.sh
    fi
    clear
}

# --- Pasang SSL (Tetap sama) ---
function pasang_ssl() {
    clear
    print_install "Memasang SSL Pada Domain"
    domain=$(cat /root/domain)
    systemctl stop nginx
    mkdir -p /root/.acme.sh
    curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
    chmod 777 /etc/xray/xray.key
    print_success "SSL Certificate"
}

# --- Setup Folder Xray (Tetap sama) ---
function make_folder_xray() {
    rm -rf /etc/vmess/.vmess.db
    rm -rf /etc/vless/.vless.db
    rm -rf /etc/trojan/.trojan.db
    rm -rf /etc/ssh/.ssh.db
    rm -rf /etc/bot/.bot.db
    mkdir -p /etc/bot
    mkdir -p /etc/vmess
    mkdir -p /etc/vless
    mkdir -p /etc/trojan
    mkdir -p /etc/shadowsocks
    mkdir -p /etc/ssh
    mkdir -p /usr/bin/xray/
    mkdir -p /var/www/html
    mkdir -p /etc/kyt/limit/vmess/ip
    mkdir -p /etc/limit/vmess
    mkdir -p /etc/user-create
    touch /etc/xray/domain
    touch /var/log/xray/access.log
    touch /var/log/xray/error.log
}

# --- Instalasi Xray dengan Config Kustom ---
function install_xray() {
    clear
    print_install "Memasang Core Xray Versi Terbaru"
    mkdir -p /run/xray
    chown www-data.www-data /run/xray
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.8.23

    domain=$(cat /etc/xray/domain)

    print_install "Mengenerate Konfigurasi Xray (Mode Sumsel)"
    # --- KONFIGURASI BARU UNTUK SUMATERA SELATAN ---
    cat > /etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$(cat /proc/sys/kernel/random/uuid)",
            "flow": "xtls-rprx-vision",
            "email": "vless-ws@${domain}"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 80
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$(cat /proc/sys/kernel/random/uuid)",
            "email": "vmess-ws@${domain}"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
        },
        "wsSettings": {
          "path": "/vmess",
          "headers": {
            "Host": "${domain}"
          }
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$(cat /proc/sys/kernel/random/uuid)",
            "email": "trojan-ws@${domain}"
          }
        ],
        "fallbacks": [
          {
            "dest": 80
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

    # --- SETUP NGINX DAN HAPROXY (Sesuai script lo) ---
    curl -s ipinfo.io/city >> /etc/xray/city
    curl -s ipinfo.io/org | cut -d " " -f 2-10 >> /etc/xray/isp

    wget -O /etc/haproxy/haproxy.cfg "${REPO}config/haproxy.cfg" >/dev/null 2>&1
    wget -O /etc/nginx/conf.d/xray.conf "${REPO}config/xray.conf" >/dev/null 2>&1
    sed -i "s/xxx/${domain}/g" /etc/haproxy/haproxy.cfg
    sed -i "s/xxx/${domain}/g" /etc/nginx/conf.d/xray.conf
    curl ${REPO}config/nginx.conf > /etc/nginx/nginx.conf
    cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/hap.pem >/dev/null

    chmod +x /etc/systemd/system/runn.service
    rm -rf /etc/systemd/system/xray.service.d

    cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com
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

    print_success "Core Xray dan Konfigurasi"
}

# --- Fungsi-Fungsi Lain (SSH, UDP, dll) Tetap Sama ---
function ssh() {
    clear
    print_install "Memasang Password SSH"
    wget -O /etc/pam.d/common-password "${REPO}files/password"
    chmod 644 /etc/pam.d/common-password
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure keyboard-configuration
    ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
    sed -i 's/^AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
    systemctl restart ssh
    print_success "Password SSH"
}

function udp_mini() {
    clear
    print_install "Memasang Service Limit IP & Quota"
    wget -q https://raw.githubusercontent.com/sshmax07/sshmax2/main/config/fv-tunnel && chmod +x fv-tunnel && ./fv-tunnel
    mkdir -p /usr/local/kyt/
    wget -q -O /usr/local/kyt/udp-mini "${REPO}files/udp-mini"
    chmod +x /usr/local/kyt/udp-mini
    wget -q -O /etc/systemd/system/udp-mini-1.service "${REPO}files/udp-mini-1.service"
    wget -q -O /etc/systemd/system/udp-mini-2.service "${REPO}files/udp-mini-2.service"
    wget -q -O /etc/systemd/system/udp-mini-3.service "${REPO}files/udp-mini-3.service"
    systemctl enable udp-mini-1 --now
    systemctl enable udp-mini-2 --now
    systemctl enable udp-mini-3 --now
    print_success "Limit IP Service"
}

function ins_SSHD() {
    clear
    print_install "Memasang SSHD"
    wget -q -O /etc/ssh/sshd_config "${REPO}files/sshd" >/dev/null 2>&1
    chmod 700 /etc/ssh/sshd_config
    systemctl restart ssh
    print_success "SSHD"
}

function ins_dropbear() {
    clear
    print_install "Menginstall Dropbear"
    apt-get install dropbear -y > /dev/null 2>&1
    wget -q -O /etc/default/dropbear "${REPO}config/dropbear.conf"
    chmod +x /etc/default/dropbear
    systemctl restart dropbear
    print_success "Dropbear"
}

function ins_vnstat() {
    clear
    print_install "Menginstall Vnstat"
    apt -y install vnstat > /dev/null 2>&1
    systemctl restart vnstat
    print_success "Vnstat"
}

function ins_backup() {
    clear
    print_install "Memasang Backup Server (Rclone)"
    apt install rclone -y
    printf "q\n" | rclone config
    wget -O /root/.config/rclone/rclone.conf "${REPO}config/rclone.conf"
    cd /bin
    git clone https://github.com/magnific0/wondershaper.git &>/dev/null
    cd wondershaper
    make install &>/dev/null
    cd
    rm -rf wondershaper
    apt install msmtp-mta ca-certificates bsd-mailx -y
    print_success "Backup Server"
}

function ins_swab() {
    clear
    print_install "Memasang Swap 1G"
    dd if=/dev/zero of=/swapfile bs=1024 count=1048576 &>/dev/null
    mkswap /swapfile &>/dev/null
    chown root:root /swapfile
    chmod 0600 /swapfile
    swapon /swapfile &>/dev/null
    echo '/swapfile      swap swap   defaults    0 0' >> /etc/fstab
    wget ${REPO}files/bbr.sh && chmod +x bbr.sh && ./bbr.sh &>/dev/null
    print_success "Swap 1G"
}

function ins_Fail2ban() {
    clear
    print_install "Menginstall Fail2ban"
    apt -y install fail2ban > /dev/null 2>&1
    systemctl enable --now fail2ban
    echo "Banner /etc/kyt.txt" >>/etc/ssh/sshd_config
    sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/kyt.txt"@g' /etc/default/dropbear
    wget -O /etc/kyt.txt "${REPO}files/issue.net"
    print_success "Fail2ban"
}

function ins_epro() {
    clear
    print_install "Menginstall ePro WebSocket Proxy"
    wget -O /usr/bin/ws "${REPO}files/ws" >/dev/null 2>&1
    wget -O /usr/bin/tun.conf "${REPO}config/tun.conf" >/dev/null 2>&1
    wget -O /etc/systemd/system/ws.service "${REPO}files/ws.service" >/dev/null 2>&1
    chmod +x /usr/bin/ws
    chmod 644 /usr/bin/tun.conf
    chmod +x /etc/systemd/system/ws.service
    systemctl daemon-reexec
    systemctl enable ws --now
    wget -q -O /usr/local/share/xray/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    wget -q -O /usr/local/share/xray/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    apt autoclean -y >/dev/null 2>&1
    apt autoremove -y >/dev/null 2>&1
    print_success "ePro WebSocket Proxy"
}

function ins_restart() {
    clear
    print_install "Merestart Semua Service"
    systemctl restart nginx
    systemctl restart xray
    systemctl restart ssh
    systemctl restart dropbear
    systemctl restart fail2ban
    systemctl restart vnstat
    systemctl restart haproxy
    systemctl restart cron
    systemctl daemon-reload
    systemctl enable nginx xray dropbear cron haproxy ws fail2ban
    history -c
    echo "unset HISTFILE" >> /etc/profile
    rm -f /root/key.pem /root/cert.pem
    print_success "Semua Service"
}

function menu() {
    clear
    print_install "Memasang Menu Packet"
    wget ${REPO}menu/menu.zip &>/dev/null
    unzip menu.zip &>/dev/null
    chmod +x menu/*
    mv menu/* /usr/local/sbin/
    rm -rf menu menu.zip
}

function profile() {
    cat >/root/.profile <<EOF
# ~/.profile: executed by Bourne-compatible login shells.
if [ "\$BASH" ]; then
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
fi
mesg n || true
menu
EOF
    cat >/etc/cron.d/xp_all <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 0 * * * root /usr/local/sbin/xp
END
    cat >/etc/cron.d/daily_reboot <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root /sbin/reboot
END
    service cron restart
    chmod +x /etc/rc.local
    print_success "Menu Packet"
}

function enable_services() {
    clear
    print_install "Enable Service"
    systemctl daemon-reload
    systemctl start netfilter-persistent
    systemctl enable rc-local
    systemctl enable --now cron
    systemctl enable --now netfilter-persistent
    print_success "Enable Service"
    clear
}

# --- MAIN INSTALLATION FUNCTION ---
function instal() {
    clear
    first_setup
    nginx_install
    base_package
    security_hardening
    firewall_setup
    make_folder_xray
    pasang_domain
    pasang_ssl
    install_xray
    ssh
    udp_mini
    ins_SSHD
    ins_dropbear
    ins_vnstat
    ins_backup
    ins_swab
    ins_Fail2ban
    ins_epro
    ins_restart
    menu
    profile
    enable_services
}

# --- EKSEKUSI SCRIPT ---
instal

echo ""
history -c
rm -rf /root/menu /root/*.zip /root/*.sh /root/LICENSE /root/README.md /root/domain
secs_to_human "$(($(date +%s) - ${start}))"
echo -e "${green} Script Berhasil Diinstall, Siap Tempur!${NC}"
echo ""
read -p "$( echo -e "Press ${YELLOW}[ ${NC}${YELLOW}Enter${NC} ${YELLOW}]${NC} Untuk Reboot") "
reboot