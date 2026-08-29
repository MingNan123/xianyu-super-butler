# Cloudflare Tunnel deployment

Target hostname: `https://xianyu.mingshop123.com`

This deployment keeps the Python/FastAPI/Playwright/Chromium application on a persistent Docker host and exposes it through a remotely-managed Cloudflare Tunnel.

## 1. Create the Cloudflare Tunnel

In Cloudflare Dashboard:

1. Go to **Networking > Tunnels**.
2. Create a tunnel named `xianyu-super-butler`.
3. Add a **Published application** route.
4. Hostname: `xianyu.mingshop123.com`.
5. Service: `http://xianyu-app:8080`.
6. Copy the tunnel token from the Docker/cloudflared install command. The token begins with `eyJ...`.

Cloudflare will automatically create the DNS record for the published hostname.

## 2. Configure the Docker host

From the repository root:

```bash
cp deploy/cloudflare/.env.example deploy/cloudflare/.env
```

Edit `deploy/cloudflare/.env` and set at minimum:

- `ADMIN_PASSWORD`
- `JWT_SECRET_KEY`
- `CLOUDFLARE_TUNNEL_TOKEN`

Do not commit the real `.env` file.

## 3. Start

From the repository root:

```bash
docker compose \
  --env-file deploy/cloudflare/.env \
  -f deploy/cloudflare/docker-compose.cloudflare.yml \
  up -d --build
```

Check status:

```bash
docker compose \
  --env-file deploy/cloudflare/.env \
  -f deploy/cloudflare/docker-compose.cloudflare.yml \
  ps
```

Check logs:

```bash
docker logs -f xianyu-super-butler
```

```bash
docker logs -f xianyu-cloudflared
```

Local health test:

```bash
curl http://127.0.0.1:8080/health
```

Public URL:

`https://xianyu.mingshop123.com`

## Security

The application port is bound to `127.0.0.1` only. Internet traffic should enter through Cloudflare Tunnel rather than exposing port 8080 directly.

The SQLite database remains under `data/` on the persistent host. Back up this directory regularly.
