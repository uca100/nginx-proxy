# Changelog

## 2026-04-07
### Added
- Initial setup: centralized nginx reverse proxy for pi5.tail075174.ts.net
- `setup.sh` — master script: issues shared Tailscale cert to `/etc/ssl/pi5/`, auto-deploys all configs from `sites/`, reloads nginx
- `sites/health-os.conf` — port 443 → Next.js on :3000
- `sites/alexa-gdrive.conf` — port 8443 → Flask/Gunicorn on :5000
- Drop-in pattern: adding a new app requires only copying a `.conf` to `sites/` and re-running `setup.sh`
