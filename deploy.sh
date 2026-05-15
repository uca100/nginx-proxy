#!/usr/bin/env bash
set -euo pipefail

PROXY_HOST="uri@192.168.40.100"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NGINX_CONF="$SCRIPT_DIR/sites/apps.conf"

echo "==> Syncing nginx config to proxy..."
scp "$NGINX_CONF" "$PROXY_HOST:/tmp/nginx-apps.conf"

echo "==> Deploying nginx config..."
ssh "$PROXY_HOST" "
  sudo mv /tmp/nginx-apps.conf /etc/nginx/sites-available/myweb
  sudo ln -sf /etc/nginx/sites-available/myweb /etc/nginx/sites-enabled/myweb
  sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/apps.conf
  sudo nginx -t
  sudo systemctl reload nginx
"

echo "==> nginx status:"
ssh "$PROXY_HOST" "sudo systemctl status nginx --no-pager | head -10"

echo ""
echo "Done! https://myweb.tail075174.ts.net"