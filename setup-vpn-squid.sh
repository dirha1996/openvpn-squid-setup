#!/bin/bash

# ================================================
#  AUTOINSTALL: OPENVPN + SQUID TRANSPARENT PROXY
# ================================================

set -e

echo "📦 Memperbarui sistem & memasang dependensi..."
apt update && apt upgrade -y
apt install curl iptables iptables-persistent squid openvpn easy-rsa -y

# --- 1. SETUP OPENVPN ---
echo "🔧 Mengkonfigurasi OpenVPN..."

VPN_NET="10.8.0.0"
VPN_MASK="255.255.255.0"
VPN_IF="tun0"
PORT=1194

cd /etc/openvpn
make-cadir easy-rsa
cd easy-rsa
./easyrsa init-pki
echo | ./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey --secret ta.key

cp pki/ca.crt pki/private/server.key pki/issued/server.crt ta.key dh.pem /etc/openvpn/

cat > /etc/openvpn/server.conf <<EOF
port ${PORT}
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA256
tls-auth ta.key 0
topology subnet
server ${VPN_NET} ${VPN_MASK}
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS ${VPN_NET%.*}.1"
keepalive 10 120
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

systemctl enable openvpn@server
systemctl start openvpn@server

# --- 2. SETUP SQUID ---
echo "🔧 Mengkonfigurasi Squid Transparent Proxy..."

cat > /etc/squid/squid.conf <<EOF
http_port 3128
http_port 3129 intercept

acl localnet src ${VPN_NET}/24
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

http_access allow localnet
http_access allow localhost
http_access deny all

request_header_access Cookie deny all
request_header_access Referer deny all
request_header_access X-Forwarded-For deny all
request_header_access Via deny all
request_header_access Cache-Control deny all
via off
forwarded_for delete

access_log /var/log/squid/access.log
EOF

systemctl enable squid
systemctl restart squid

# --- 3. IPTABLES REDIRECT (Transparent Proxy) ---
echo "⚙️ Menambahkan aturan iptables untuk redirect proxy..."

iptables -t nat -A PREROUTING -s ${VPN_NET}/24 -p tcp --dport 80 -j REDIRECT --to-port 3129
iptables -t nat -A POSTROUTING -s ${VPN_NET}/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -s ${VPN_NET}/24 -j ACCEPT

netfilter-persistent save

# --- 4. ENABLE IP FORWARDING ---
echo "✅ Mengaktifkan IP forwarding..."

sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
sysctl -p

# --- 5. SELESAI ---
echo -e "\n✅ INSTALASI SELESAI!"
echo "🔑 Sekarang buat user VPN dengan: ./easyrsa build-client-full nama_client nopass"
echo "📁 File .ovpn bisa dibuat manual dari template, atau saya bantu jika dibutuhkan."
