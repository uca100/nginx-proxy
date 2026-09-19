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

    if [[ "$HTTP_CODE" =~ ^[23] ]]; then
        # 2xx and 3xx both mean the backend is alive — the auth gateway 302-redirects
        # "/" to /auth/login, which is healthy. Asserting ==200 here fired the recovery
        # branch on every run and restarted nginx every 5 min, cutting in-flight streams.
        log "OK — Funnel active, backend HTTP $HTTP_CODE"

    elif [ "$HTTP_CODE" = "000" ]; then
        # curl could not connect at all — nginx is down or hung. This is the ONLY case
        # that justifies a restart. The funnel is fine, so leave it alone: resetting it
        # drops the public :443 listener and kills every in-flight request.
        log "Backend unreachable (curl $HTTP_CODE) — restarting nginx"
        systemctl restart nginx
        sleep 2
        AFTER=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$FUNNEL_PORT/")
        log "nginx restarted — backend now HTTP $AFTER"

    else
        # 4xx/5xx: nginx is answering, so restarting it fixes nothing — a 5xx is an
        # upstream app error. Record it and leave recovery to app-level monitoring.
        log "WARN — backend HTTP $HTTP_CODE (nginx is up; not restarting)"
    fi
fi
