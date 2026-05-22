#!/usr/bin/env bash
# install.sh — nginx-proxy (Reverse Proxy + TLS on tec/192.168.40.100)
# Run ON tec (192.168.40.100) as the 'uri' user.
# Idempotent: safe to re-run after config changes.
#
# This wraps setup.sh (which handles nginx install, TLS cert, and site configs).
# Use deploy.sh from mac for routine config updates (no SSH keys needed for setup).
#
# Usage: bash install.sh
# Prerequisites:
#   - Tailscale installed and auth'd on tec
#   - SSH key access from mac to tec (uri@192.168.40.100)
#   - tailscale cert working (myweb.tail075174.ts.net)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> [nginx-proxy] Starting install/update..."

# ── 1. Prerequisites check ─────────────────────────────────────────────────
echo "==> Checking prerequisites..."

if ! command -v tailscale &>/dev/null; then
  echo "ERROR: Tailscale not installed. Install and auth first:"
  echo "  curl -fsSL https://tailscale.com/install.sh | sh"
  echo "  sudo tailscale up"
  exit 1
fi

if ! command -v nginx &>/dev/null; then
  echo "==> nginx not installed — setup.sh will install it."
fi

# ── 2. Run setup.sh (nginx install + TLS cert + site configs) ──────────────
echo "==> Running setup.sh..."
bash "${SCRIPT_DIR}/setup.sh"

echo ""
echo "==> [nginx-proxy] Install complete."
echo "    All app sites from ${SCRIPT_DIR}/sites/*.conf are now active."
echo "    TLS cert: /etc/ssl/myweb/cert.pem"
echo "    URL:      https://myweb.tail075174.ts.net"
echo ""
echo "==> To add a new app site:"
echo "    1. Add .conf file to ${SCRIPT_DIR}/sites/"
echo "    2. Run: ./deploy.sh (from mac)"
echo "    OR re-run this script on tec"
