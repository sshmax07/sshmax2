#!/bin/bash

echo "🔥 INSTALL ANTI TELKOMSEL START 🔥"

# Update
apt update -y && apt upgrade -y

# Install dependency
apt install -y curl wget nginx haproxy socat cron

# Install Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# Generate Reality Key
KEY=$(xray x25519 | grep Private | awk '{print $3}')
PUB=$(xray x25519 | grep Public | awk '{print $3}')

# Save info
echo "UUID: $UUID" > /root/info.txt
echo "PUBLIC KEY: $PUB" >> /root/info.txt

# =========================
# XRAY CONFIG
# =========================

cat > /etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [{
          "id": "$UUID",
          "flow": "xtls-rprx-vision"
        }],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.cloudflare.com:443",
          "serverNames": ["www.cloudflare.com"],
          "privateKey": "$KEY",
          "shortIds": ["abcd1234"]
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "$UUID"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/zoom",
          "headers": {"Host": "support.zoom.us"}
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "$UUID"}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/cf",
          "headers": {"Host": "104.17.3.81"}
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "trojan",
      "settings": {
        "clients": [{"password": "$UUID"}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/huya",
          "headers": {"Host": "ir.huya.com"}
        }
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# =========================
# NGINX
# =========================

cat > /etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 80;

    location /zoom {
        proxy_pass http://127.0.0.1:10001;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /cf {
        proxy_pass http://127.0.0.1:10002;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /huya {
        proxy_pass http://127.0.0.1:10003;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# =========================
# HAPROXY
# =========================

cat > /etc/haproxy/haproxy.cfg <<EOF
frontend tls
    bind *:443
    mode tcp

    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }

    use_backend zoom if { req.ssl_sni -i support.zoom.us }
    use_backend cf if { req.ssl_sni -i 104.17.3.81 }
    use_backend huya if { req.ssl_sni -i ir.huya.com }

    default_backend nginx

backend zoom
    server srv1 127.0.0.1:80

backend cf
    server srv2 127.0.0.1:80

backend huya
    server srv3 127.0.0.1:80

backend nginx
    server srv4 127.0.0.1:80
EOF

# =========================
# AUTO BUG SWITCH
# =========================

cat > /usr/local/bin/bug-switch.sh <<EOF
#!/bin/bash
for bug in support.zoom.us 104.17.3.81 ir.huya.com; do
    timeout 2 bash -c "echo > /dev/tcp/\$bug/443" 2>/dev/null
    if [ \$? -eq 0 ]; then
        echo \$bug > /etc/xray/bug_active
        break
    fi
done
EOF

chmod +x /usr/local/bin/bug-switch.sh

echo "*/2 * * * * root /usr/local/bin/bug-switch.sh" > /etc/cron.d/bug

# Restart
systemctl restart xray
systemctl restart nginx
systemctl restart haproxy
systemctl enable xray nginx haproxy

echo ""
echo "🔥 INSTALL SELESAI 🔥"
echo "UUID: $UUID"
echo "PUBLIC KEY: $PUB"
echo "=============================="
