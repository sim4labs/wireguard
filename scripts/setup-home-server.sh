#!/bin/bash
set -e

# Usage: ./setup-home-server.sh <config-file>
# Example: ./setup-home-server.sh server1.conf

if [ -z "$1" ]; then
  echo "Usage: $0 <wireguard-config-file>"
  echo "Example: $0 server1.conf"
  exit 1
fi

CONFIG_FILE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file '$CONFIG_FILE' not found"
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)"
  exit 1
fi

echo "Setting up WireGuard on home server..."

# Install WireGuard
if command -v apt-get &> /dev/null; then
  apt-get update
  apt-get install -y wireguard
elif command -v dnf &> /dev/null; then
  dnf install -y wireguard-tools
elif command -v yum &> /dev/null; then
  yum install -y wireguard-tools
else
  echo "Error: Unsupported package manager. Install WireGuard manually."
  exit 1
fi

# Enable IP forwarding
cat > /etc/sysctl.d/99-wireguard.conf <<EOF
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Copy config
cp "$CONFIG_FILE" /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

# Enable and start WireGuard (always-on, survives reboots)
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

echo ""
echo "WireGuard setup complete!"
echo "Status:"
wg show wg0
echo ""
echo "The WireGuard tunnel is now active and will start automatically on boot."
echo "To check status:  sudo wg show"
echo "To restart:       sudo systemctl restart wg-quick@wg0"
echo "To stop:          sudo systemctl stop wg-quick@wg0"
