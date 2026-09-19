# Changelog


## [Unreleased] - 2026-09-19

### Fixed
- **`tailscale-watchdog.sh` restarted nginx every 5 minutes for four months.** Its
  backend health check compared `curl` output against exactly `200`, but `/` returns
  **302** (the auth gateway redirects to `/auth/login`), so the "backend is down"
  branch fired on *every* run: `funnel reset` → `systemctl restart nginx` →
  `funnel --bg`. The public `:443` listener disappeared for 3–4 s each cycle.
  - Broke **2026-05-15T10:01Z**, the day `/` started redirecting. The watchdog log
    shows the transition: last `OK — backend HTTP 200` at 09:55:52Z, first
    `backend returned HTTP 302` at 10:01:10Z, then **35,032** consecutive failures.
  - Fix: accept any 2xx/3xx as healthy (`! [[ "$HTTP_CODE" =~ ^[23] ]]`). A 302 from
    an auth gateway means the backend is alive; `000` (timeout/refused) and 5xx still
    trigger recovery.
  - **Impact was not limited to nginx reloads** — it broke long-lived downloads for
    every app behind the proxy. Diagnosed via alexa-gdrive, where 90-minute MP3
    streams died with `MEDIA_ERROR_INVALID_REQUEST`: the Echo's Range re-requests
    landed in a teardown window and never reached nginx, so *nothing was logged*.
  - **Lesson: health checks must assert the property they care about (is the backend
    reachable), not an incidental one (is the status exactly 200).** A recovery action
    with a side effect as broad as `systemctl restart nginx` needs a check that cannot
    false-positive, and the watchdog's own log should be alerted on — 35,032 identical
    failures went unnoticed because nothing read it.

### Added
- `tailscale-watchdog.sh` + `.service` + `.timer` are now **version-controlled here**.
  They previously existed only as root-owned files on tec, untracked anywhere — which
  is why a script restarting nginx every 5 minutes went unreviewed for four months.


## [Unreleased] - 2026-09-18

### Removed
- **Reverted the `/photos/` → photofield route added earlier the same day.** It served a
  blank page and cannot be made to work by proxying.
  - The asset problem *was* solved (trailing-slash `proxy_pass` prefix strip +
    `sub_filter` on the HTML + `photofield-api-host` cookie for the API base) — HTML,
    JS (1,830,985 B byte-identical) and CSS all returned 200.
  - The real blocker is **client-side**: photofield's Vue Router calls
    `createWebHistory()` with no base and declares only `/`,
    `/collections/:collectionId` and `/collections/:collectionId/:regionId`. Under a
    `/photos` prefix the router matches nothing, renders an empty view, and issues zero
    API calls. No server-side rewrite can fix this — the comparison happens in the
    browser against the address bar, and `window.location` isn't writable.
  - Upstream **SmilyOrg/photofield#103 "Support subpaths" is open since 2024-02-25**;
    the maintainer states the app *requires deployment at the root of a (sub)domain*.
- **Lesson: verifying that asset URLs resolve does not prove an SPA works under a
  subpath.** Check the router base (`createWebHistory` argument / `basePath` / `<base>`)
  before designing a prefix-stripping block.

### Changed
- photofield is now reached as a direct `http://192.168.40.99:3016` **service** link from
  the myweb landing page, the same pattern as Pi-hole and Uptime Kuma, which are also
  root-only web UIs.

### Security
- **Consequence of the above: photofield is no longer behind the auth gateway.** It has
  no login of its own, so the entire family photo archive is readable by anything on the
  LAN. The previously proposed `DOCKER-USER` rule to block port 3016 is now mutually
  exclusive with the landing-page link — applying it would break the only working route.
  Accepted deliberately; revisit if the app ever moves to its own Tailscale hostname.

## [Unreleased] - 2026-06-27

### Fixed
- Added missing `/alwayson/terminal/pi4i/` nginx location block proxying to Pi5:7684 (Nomaglio server via Tailscale)

## [Unreleased] - 2026-06-13

### Fixed
- Removed 301 redirect from `/brief` → `/brief/` and consolidated to single no-slash location block (per routing rules)
- Restarted `morning-brief.service` which was inactive (dead), causing 502 Bad Gateway on `/brief`

## [Unreleased] - 2026-05-23

### Added
- install.sh: full idempotent setup script for fresh server restore
- Mirrored to ~/projects/install-scripts/nginx-proxy.sh
- Architecture diagram and folder structure added to Notion project page

## [Unreleased] - 2026-04-18

### Changed
- `/backup/` route moved from port 3008 (unused) to myweb on port 3004
- Added `/api/backup/` route pointing to myweb (3004), before Flask catch-all

## [Unreleased] - 2026-04-17
### Added
- `deploy.sh` — syncs nginx config to proxy and reloads nginx
- `deploy-app.sh` — deploy new app: build, sync to pi5, open firewall port, print nginx route TODO

### Fixed
- Restored full `apps.conf` with all routes

## 2026-04-08
### Added
- `bootstrap.sh` — installs Tailscale with hostname `myweb` on new Ubuntu server (192.168.40.100)
- Path-based routing: `/health` → health-os, `/alexa/` → alexa-gdrive (single port 443)
- Tailscale Funnel configured on myweb (port 8080 internal → 443 external)

### Changed
- Migrated nginx from pi5 (192.168.40.99) to myweb (192.168.40.100); apps stay on pi5
- Gunicorn bound to `0.0.0.0:5000` (was `127.0.0.1`) to allow cross-server proxying
- Added `basePath: '/health'` to Next.js config; nginx rewrites `/api/` → `/health/api/` for health-os
- Health-os API routes routed explicitly; all other `/api/` routes fall through to Flask (alexa)
- `/health` redirects to `/health/dashboard`
- nginx disabled on pi5 (no longer needed)

### Fixed
- Alexa skill POST endpoint: added exact `location = /alexa` to avoid redirect (Amazon doesn't follow redirects)
- HTTPS redirect for `/health` was leaking internal port 8080 — now uses `https://$host` explicitly

### Changed
- Migrated nginx reverse proxy from pi5 (192.168.40.99) to new dedicated server myweb (192.168.40.100)
- Updated `setup.sh` hostname to `myweb.tail075174.ts.net`, cert dir to `/etc/ssl/myweb`
- Updated `sites/alexa-gdrive.conf` — listen on `192.168.40.100:443`, proxy to `192.168.40.99:5000`
- Updated `sites/health-os.conf` — listen on `192.168.40.100:8443`, proxy to `192.168.40.99:3000`
- Apps remain on pi5; only the nginx proxy layer moved to myweb

## 2026-04-07 (session 2)
### Fixed
- nginx now binds to LAN IP only (`192.168.40.99`) — avoids conflict with Tailscale Funnel (`tailscaled` owns 443/8443 on Tailscale IP)
- Removed port 80 listener — Pi-hole (pihole-FTL) owns port 80

### Changed
- Port assignments corrected to match Tailscale Funnel routing: alexa-gdrive on `:443`, health-os on `:8443`
- Pi-hole moved to port `8080` (`http://192.168.40.99:8080/admin`)

## 2026-04-07
### Added
- Initial setup: centralized nginx reverse proxy for pi5.tail075174.ts.net
- `setup.sh` — master script: issues shared Tailscale cert to `/etc/ssl/pi5/`, auto-deploys all configs from `sites/`, reloads nginx
- `sites/health-os.conf` — port 443 → Next.js on :3000
- `sites/alexa-gdrive.conf` — port 8443 → Flask/Gunicorn on :5000
- Drop-in pattern: adding a new app requires only copying a `.conf` to `sites/` and re-running `setup.sh`
