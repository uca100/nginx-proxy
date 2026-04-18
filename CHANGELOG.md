# Changelog

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
