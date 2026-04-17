#!/usr/bin/env bash
set -euo pipefail

APP="$1"
PORT="$2"

PI5="uri@192.168.40.99"
APP_DIR="/usr/local/$APP"
LOCAL_DIR="$(cd "$(dirname "$0")/../$APP" 2>/dev/null && pwd)"

if [[ -z "$LOCAL_DIR" ]]; then
  echo "Error: App directory ~/projects/$APP not found"
  exit 1
fi

echo "==> [1/4] Building $APP..."
cd "$LOCAL_DIR" && npm run build

echo "==> [2/4] Syncing to pi5..."
rsync -av --delete \
  --exclude=node_modules \
  --exclude=.git \
  --exclude=.next/cache \
  --exclude=.env.local \
  "$LOCAL_DIR/" "$PI5:$APP_DIR/"

ssh "$PI5" "cd $APP_DIR && npm install --omit=dev"

echo "==> [3/4] Opening firewall port $PORT..."
ssh "$PI5" "sudo ufw allow from 192.168.40.100 to any port $PORT proto tcp"

echo "==> [4/4] Adding nginx route for /$APP..."
echo "TODO: Add nginx location block to apps.conf manually"

echo ""
echo "Done! $APP on port $PORT"
echo "Add nginx route: location /$APP { proxy_pass http://192.168.40.99:$PORT; }"