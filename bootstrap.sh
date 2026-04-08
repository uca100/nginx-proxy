#!/usr/bin/env bash
# bootstrap.sh — run this ONCE on the new Ubuntu server (192.168.40.100)
# to install Tailscale and bring it up with the hostname "myweb"
#
# Usage:
#   scp bootstrap.sh user@192.168.40.100:~
#   ssh user@192.168.40.100 "sudo bash bootstrap.sh"
#
# After running, open the printed auth URL in your browser to approve the node,
# then set the machine name to "myweb" in the Tailscale admin console:
#   https://login.tailscale.com/admin/machines
set -euo pipefail

TAILSCALE_HOSTNAME="myweb"

echo "==> [1/3] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "==> [2/3] Bringing up Tailscale (hostname: $TAILSCALE_HOSTNAME)..."
sudo tailscale up --hostname="$TAILSCALE_HOSTNAME"

echo "==> [3/3] Verifying Tailscale status..."
sudo tailscale status

echo ""
echo "=================================================================="
echo "  Tailscale is up."
echo ""
echo "  Next steps:"
echo "    1. Approve this machine in the Tailscale admin console if needed:"
echo "       https://login.tailscale.com/admin/machines"
echo "    2. Verify the hostname shows as '$TAILSCALE_HOSTNAME'"
echo "    3. Clone this repo on the new server:"
echo "       git clone <your-repo-url> nginx-proxy"
echo "    4. Run the main setup:"
echo "       sudo ./nginx-proxy/setup.sh"
echo "=================================================================="
