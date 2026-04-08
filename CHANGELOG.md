# Changelog

## 2026-04-08
### Added
- `bootstrap.sh` — installs Tailscale with hostname `myweb` on new Ubuntu server (192.168.40.100)

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
