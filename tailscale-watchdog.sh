#!/bin/bash
# Tailscale Funnel watchdog — checks DERP reachability AND Funnel status
# Runs every 5 minutes via systemd timer

LOG=/var/log/tailscale-watchdog.log
FUNNEL_PORT=8080
TS_CMD=/usr/bin/tailscale

# Telegram alerting (NOC bot). Secrets live in a root-only 600 file, never here.
ALERT_ENV=/usr/local/bin/watchdog-alert.env
STATE_DIR=/var/lib/tailscale-watchdog
ALERT_REPEAT_SECS=21600   # re-alert on a still-failing condition every 6h, not every 5m

log() { echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ'): $*" >> "$LOG"; }

# alert <key> <message>
#
# Sends to Telegram, but only the FIRST time a given condition appears (and then at
# most once per ALERT_REPEAT_SECS while it persists). Without this dedup a stuck
# condition would fire 288 messages a day and be muted within the hour — which is the
# failure mode that let 35,032 bad runs go unnoticed for four months.
alert() {
    local key="$1" msg="$2" stamp now
    [ -r "$ALERT_ENV" ] || return 0
    # shellcheck disable=SC1090
    . "$ALERT_ENV"
    [ -n "${WATCHDOG_TG_TOKEN:-}" ] && [ -n "${WATCHDOG_TG_CHAT:-}" ] || return 0

    mkdir -p "$STATE_DIR"
    stamp="$STATE_DIR/alert-$key"
    now=$(date +%s)
    if [ -f "$stamp" ] && [ $(( now - $(cat "$stamp" 2>/dev/null || echo 0) )) -lt "$ALERT_REPEAT_SECS" ]; then
        return 0
    fi
    echo "$now" > "$stamp"

    curl -s -o /dev/null --max-time 10 \
        -X POST "https://api.telegram.org/bot${WATCHDOG_TG_TOKEN}/sendMessage" \
        -d "chat_id=${WATCHDOG_TG_CHAT}" \
        --data-urlencode "text=$(hostname) watchdog: ${msg}" || true
}

# clear_alert <key> — condition resolved; next occurrence alerts immediately
clear_alert() { rm -f "$STATE_DIR/alert-$1" 2>/dev/null || true; }

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
    alert derp "DERP unreachable from all 5 relays — restarting tailscaled"
    systemctl restart tailscaled
    sleep 5
else
    clear_alert derp
fi

# ── 2. Check Funnel is active and serving ─────────────────────────────────────
FUNNEL_STATUS=$($TS_CMD funnel status 2>&1)

if ! echo "$FUNNEL_STATUS" | grep -q "Funnel on"; then
    log "Funnel not active — resetting and re-enabling"
    alert funnel "Tailscale Funnel was OFF — resetting and re-enabling on :$FUNNEL_PORT. The public URL was unreachable until now."
    $TS_CMD funnel reset 2>/dev/null
    sleep 1
    $TS_CMD funnel --bg --yes "$FUNNEL_PORT"
    log "Funnel re-enabled on port $FUNNEL_PORT"
else
    clear_alert funnel
    # ── 3. Funnel says on — verify backend actually responds ──────────────────
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$FUNNEL_PORT/")

    if [[ "$HTTP_CODE" =~ ^[23] ]]; then
        # 2xx and 3xx both mean the backend is alive — the auth gateway 302-redirects
        # "/" to /auth/login, which is healthy. Asserting ==200 here fired the recovery
        # branch on every run and restarted nginx every 5 min, cutting in-flight streams.
        log "OK — Funnel active, backend HTTP $HTTP_CODE"
        clear_alert backend
        clear_alert backend_err

    elif [ "$HTTP_CODE" = "000" ]; then
        # curl could not connect at all — nginx is down or hung. This is the ONLY case
        # that justifies a restart. The funnel is fine, so leave it alone: resetting it
        # drops the public :443 listener and kills every in-flight request.
        log "Backend unreachable (curl $HTTP_CODE) — restarting nginx"
        systemctl restart nginx
        sleep 2
        AFTER=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$FUNNEL_PORT/")
        log "nginx restarted — backend now HTTP $AFTER"
        alert backend "nginx was unreachable on :$FUNNEL_PORT — restarted it. Backend now HTTP $AFTER. In-flight requests for all apps were dropped."

    else
        # 4xx/5xx: nginx is answering, so restarting it fixes nothing — a 5xx is an
        # upstream app error. Record it and leave recovery to app-level monitoring.
        log "WARN — backend HTTP $HTTP_CODE (nginx is up; not restarting)"
        alert backend_err "backend returned HTTP $HTTP_CODE on :$FUNNEL_PORT. nginx is up, so this is an upstream app error — not restarting anything."
    fi
fi
