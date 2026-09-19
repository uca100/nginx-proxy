#!/bin/bash
# Tailscale Funnel watchdog — checks DERP reachability AND Funnel status
# Runs every 5 minutes via systemd timer

LOG=/var/log/tailscale-watchdog.log
FUNNEL_PORT=8080
TS_CMD=/usr/bin/tailscale

log() { echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'): $*" >> "$LOG"; }

# ── 1. Check DERP reachability ────────────────────────────────────────────────
DERP_IPS=(
    176.58.90.147   # par
    176.58.93.248   # ams
    167.235.72.200  # nue
    45.159.97.144   # mad
    185.40.234.219  # fra
)

DERP_OK=0
for ip in "${DERP_IPS[@]}"; do
    if timeout 3 bash -c "</dev/tcp/$ip/443" 2>/dev/null; then
        DERP_OK=1
        break
    fi
done

if [ "$DERP_OK" -eq 0 ]; then
    log "DERP unreachable — restarting tailscaled"
    systemctl restart tailscaled
    sleep 5
fi

# ── 2. Check Funnel is active and serving ─────────────────────────────────────
FUNNEL_STATUS=$($TS_CMD funnel status 2>&1)

if ! echo "$FUNNEL_STATUS" | grep -q "Funnel on"; then
    log "Funnel not active — resetting and re-enabling"
    $TS_CMD funnel reset 2>/dev/null
    sleep 1
    $TS_CMD funnel --bg --yes "$FUNNEL_PORT"
    log "Funnel re-enabled on port $FUNNEL_PORT"
else
    # ── 3. Funnel says on — verify backend actually responds ──────────────────
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$FUNNEL_PORT/")
    # 2xx and 3xx both mean the backend is alive — the auth gateway 302-redirects
    # "/" to /auth/login, which is healthy. Only 5xx or 000 (timeout/refused) are
    # real failures. Matching ==200 fired this branch on every run and restarted
    # nginx every 5 min, cutting in-flight streams.
    if ! [[ "$HTTP_CODE" =~ ^[23] ]]; then
        log "Funnel active but backend returned HTTP $HTTP_CODE — resetting funnel and restarting nginx"
        $TS_CMD funnel reset 2>/dev/null
        sleep 1
        systemctl restart nginx
        sleep 2
        $TS_CMD funnel --bg --yes "$FUNNEL_PORT"
        log "Funnel re-enabled, nginx restarted"
    else
        log "OK — Funnel active, backend HTTP $HTTP_CODE"
    fi
fi
