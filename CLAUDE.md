## Project Reference

- **Project #**: 09
- **Notion Page**: https://www.notion.so/33ba26f61658814795f7dc7d2487bdf0

## Versioning

Every deployment must include a version number:
- **In the app**: Display in the UI (footer, `/version` endpoint, or about page)
- **In GitHub**: Tag the release (`git tag vX.Y.Z && git push --tags`)
- **In Notion**: Record the version number in the project's Recent Changes section

---

## Architecture

Three listeners on `tec` (192.168.40.100):
- `192.168.40.100:80` — HTTP, redirects to HTTPS
- `192.168.40.100:443` — LAN HTTPS (Tailscale cert)
- `127.0.0.1:8080` — Tailscale Funnel entry point (**DO NOT REMOVE**)

All apps live on `pi5` (192.168.40.99). nginx proxies from tec → pi5.

Public URL: `https://myweb.tail075174.ts.net`

---

## URL Rules — READ BEFORE ADDING ANY ROUTE

### No trailing slashes — ever

**All public-facing paths must be without a trailing slash.**

- Cards, links, and navigation always link to `/path` not `/path/`
- nginx location blocks use `location /path {` not `location /path/ {`
- Never use `return 301 .../path/` — browsers cache 301s permanently. If a redirect is ever needed, use `302`.

**Why:** A cached 301 with trailing slash caused Chrome to permanently redirect to `http://host:8080/path/` (the internal Funnel port) — unreachable from the browser. Safari and incognito were unaffected because they don't cache the same way. This took many sessions to diagnose.

### One location block per app — no duplicates

Never add multiple overlapping location blocks for the same app (e.g. `/trading-ibkr`, `/trading-ibkr/`, `/trading-ibkr/_next/`). Extra blocks conflict and route asset requests incorrectly, causing CSS/JS to 404 and the page to load blank.

For Next.js apps with `basePath`, a single `location /myapp` block handles everything — the app serves all its assets under `/myapp/_next/...` automatically.

### Proxy directly — no redirect chains

Do not use a redirect + separate proxy block pattern:
```nginx
# WRONG — creates a redirect chain, 301 gets cached, causes browser failures
location = /myapp { return 301 https://$host/myapp/; }
location /myapp/ { proxy_pass http://192.168.40.99:PORT/; }

# RIGHT — single block, no redirect, no trailing slash
location /myapp {
    proxy_pass http://192.168.40.99:PORT/;
    ...
}
```

---

## App Types and nginx Patterns

### Flask / Gunicorn apps
Flask apps are deployed at `/` internally. nginx strips the prefix via `proxy_pass` with trailing slash:

```nginx
location /myapp {
    auth_request       /auth/check;
    error_page 401   = @auth_login;
    proxy_pass         http://192.168.40.99:PORT/;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
}
```

Note: `proxy_pass http://192.168.40.99:PORT/;` (trailing slash on the upstream URL) strips `/myapp` from the path. The app receives requests at `/`.

### Next.js apps (with basePath)
Next.js apps use `basePath: "/myapp"` in `next.config.ts`. nginx proxies without stripping the prefix:

```nginx
location /myapp {
    auth_request       /auth/check;
    error_page 401   = @auth_login;
    proxy_pass         http://192.168.40.99:PORT;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_set_header   Upgrade    $http_upgrade;
    proxy_set_header   Connection "upgrade";
}
```

Note: `proxy_pass http://192.168.40.99:PORT;` (NO trailing slash) — the full `/myapp` path is forwarded to the app, which expects it via `basePath`.

### Key difference: Flask vs Next.js proxy_pass
| App type | proxy_pass | Why |
|----------|-----------|-----|
| Flask | `http://pi5:PORT/` | Trailing slash strips the prefix; Flask serves at `/` |
| Next.js | `http://pi5:PORT` | No trailing slash; Next.js expects full path via basePath |

---

## Adding a New App — Step by Step

1. **Choose a port** on pi5 (see ARCHITECTURE.md for used ports)

2. **Add the nginx location block** in `sites/apps.conf`:
   - Flask: use trailing slash on proxy_pass upstream
   - Next.js: no trailing slash on proxy_pass upstream
   - No trailing slash in the `location` path
   - Always include `auth_request /auth/check;` unless the app is explicitly public

3. **Deploy nginx:**
   ```bash
   cd ~/projects/nginx-proxy && ./deploy.sh
   ```

4. **Open the port on pi5 firewall** (if new):
   ```bash
   ssh pi5 "sudo ufw allow from 192.168.40.100 to any port PORT proto tcp"
   ```

5. **Add the app card to myweb** — see myweb/CLAUDE.md

6. **Update ARCHITECTURE.md** with the new port/app entry

---

## Auth

Every app must include auth unless explicitly public:
```nginx
auth_request       /auth/check;
error_page 401   = @auth_login;
```

The auth service runs on pi5:4001. It validates session cookies and returns 200 (pass) or 401 (redirect to login).
