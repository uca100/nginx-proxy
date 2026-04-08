#!/usr/bin/env bash
# nginx-proxy/setup.sh — master nginx + TLS setup for myweb.tail075174.ts.net
#
# HOW TO ADD A NEW APP:
#   1. Write your app's nginx.conf (use sites/alexa-gdrive.conf as template)
#   2. Pick an unused port:
#        443, 8443, 10000  — Tailscale Funnel (internet-exposed)
#        any other port    — Tailscale network only
#   3. Copy the config here:
#        cp /path/to/your-app/nginx.conf nginx-proxy/sites/your-app.conf
#   4. Re-run: sudo ./setup.sh
#
# That's it. No changes to this script or any existing app needed.
set -euo pipefail

HOSTNAME="myweb.tail075174.ts.net"
CERT_DIR="/etc/ssl/myweb"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SITES_DIR="$SCRIPT_DIR/sites"

# ── [1/4] Ensure nginx is installed ───────────────────────────────────────────
echo "==> [1/4] Installing nginx (if not present)..."
sudo apt-get update -qq
sudo apt-get install -y nginx

# ── [2/4] Issue shared Tailscale TLS certificate ──────────────────────────────
echo "==> [2/4] Issuing shared Tailscale TLS certificate..."
echo "    Hostname : $HOSTNAME"
echo "    Cert dir : $CERT_DIR"

sudo mkdir -p "$CERT_DIR"
sudo tailscale cert \
  --cert-file "$CERT_DIR/cert.pem" \
  --key-file  "$CERT_DIR/key.pem" \
  "$HOSTNAME"

sudo chmod 640 "$CERT_DIR/key.pem"
sudo chown root:www-data "$CERT_DIR/key.pem"
sudo chmod 644 "$CERT_DIR/cert.pem"

echo "    Certificate written to $CERT_DIR"

# ── [3/4] Deploy all configs from sites/ ──────────────────────────────────────
echo "==> [3/4] Deploying nginx site configs from $SITES_DIR..."

sudo rm -f /etc/nginx/sites-enabled/default

shopt -s nullglob
configs=("$SITES_DIR"/*.conf)

if [ ${#configs[@]} -eq 0 ]; then
  echo "    [WARN] No .conf files found in $SITES_DIR — nothing to deploy."
else
  for conf in "${configs[@]}"; do
    name="$(basename "$conf" .conf)"
    dest="/etc/nginx/sites-available/$name"
    echo "    [$name] $conf → $dest"
    sudo cp "$conf" "$dest"
    sudo ln -sf "$dest" "/etc/nginx/sites-enabled/$name"
  done
fi

# ── [4/4] Validate and reload nginx ───────────────────────────────────────────
echo "==> [4/4] Testing and reloading nginx..."
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl reload nginx

echo ""
echo "=================================================================="
echo "  nginx-proxy setup complete."
echo ""
echo "  Active sites:"
for conf in "${configs[@]}"; do
  name="$(basename "$conf" .conf)"
  port=$(grep -oP '(?<=listen )\d+' "$conf" | head -1)
  echo "    $name  →  https://$HOSTNAME:$port"
done
echo ""
echo "  Shared cert: $CERT_DIR/cert.pem"
echo ""
echo "  To add a new app:"
echo "    cp /path/to/app/nginx.conf $SITES_DIR/app-name.conf"
echo "    sudo $SCRIPT_DIR/setup.sh"
echo "=================================================================="
