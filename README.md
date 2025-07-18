# OpenVPN + Squid Transparent Proxy Setup

This bash script will auto-install and configure:

- OpenVPN server (UDP 1194)
- Squid transparent proxy (port 3129)
- HTTP traffic redirection from VPN clients
- Cookie and tracker header blocking via Squid
- Iptables rules for transparent filtering

## Usage

```bash
chmod +x setup-vpn-squid.sh
sudo ./setup-vpn-squid.sh
