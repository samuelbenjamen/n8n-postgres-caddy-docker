# 🚀 Production-Ready n8n Deployment on Ubuntu 25.04 via Docker Compose (PostgreSQL & Caddy)

> A complete, production-grade setup to run **n8n** on an **Ubuntu 25.04** VM using **Docker Compose**, **PostgreSQL** for persistent storage, and **Caddy** as a reverse proxy with automatic HTTPS.

---

## Suggested GitHub repository

* **Repository name:** `n8n-ubuntu25-docker`
* **Description:** `Production-ready n8n deployment on Ubuntu 25.04 using Docker Compose, PostgreSQL and Caddy (auto HTTPS) — includes scripts for server preparation and stack deployment.`
* **Default branch:** `main`
* **Suggested files:** `README.md`, `01_prepare_server.sh`, `02_deploy_stack.sh`, `docker-compose.yml`, `.env.example`, `Caddyfile`, `LICENSE` (MIT suggested), `.gitignore`.

---

## Quick overview & goals

1. Clean start on Ubuntu 25.04.
2. Docker Engine + Docker Compose plugin installed.
3. PostgreSQL for n8n persistence.
4. n8n exposes port **5678** on the host for local/IP testing (e.g., `http://192.168.1.10:5678`).
5. Caddy handles automatic TLS for the public domain via environment variable `DOMAIN_NAME`.
6. Provide two scripts:

   * `01_prepare_server.sh` — one-time server prep.
   * `02_deploy_stack.sh` — build/start stack and restart after reboots.

---

## Repository file tree (recommended)

```
n8n-ubuntu25-docker/
├── 01_prepare_server.sh
├── 02_deploy_stack.sh
├── docker-compose.yml
├── Caddyfile
├── .env.example
├── README.md  <-- this document (short form)
├── LICENSE
└── .gitignore
```

---

# A. `01_prepare_server.sh` — Initial Server Preparation

Save this file as `01_prepare_server.sh` and make it executable (`chmod +x 01_prepare_server.sh`). It is intended to be run once on a fresh Ubuntu 25.04 VM.

```bash
#!/usr/bin/env bash
set -euo pipefail

# 01_prepare_server.sh
# One-time preparation for Ubuntu 25.04 to run Docker-based n8n stack.

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root." >&2
  exit 1
fi

EXPORT_USER=${SUDO_USER:-$(whoami)}

echo "==> 1) Removing old Docker/Docker Compose installations (if any)"
apt-get remove -y docker docker-engine docker.io containerd runc docker-compose-plugin || true
rm -rf /var/lib/docker /var/lib/containerd /etc/docker || true

echo "==> 2) Installing prerequisites"
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

echo "==> 3) Adding Docker official GPG key and repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)

echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update

echo "==> 4) Installing Docker Engine, containerd and Docker Compose plugin"
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> 5) Enabling and starting Docker"
systemctl enable --now docker

echo "==> 6) Add current user (${EXPORT_USER}) to 'docker' group (so they can run docker without sudo)"
if id -nG "${EXPORT_USER}" | grep -qw docker; then
  echo "User ${EXPORT_USER} already in docker group"
else
  usermod -aG docker "${EXPORT_USER}"
  echo "Added ${EXPORT_USER} to docker group. You may need to re-login for group change to take effect."
fi

echo "==> 7) Installing and configuring UFW (firewall)"
apt-get install -y ufw

# Allow SSH so user doesn't lock themselves out
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 5678/tcp

# Enable UFW non-interactively
ufw --force enable

echo "==> 8) Final checks"
# Print versions
echo "Docker version: $(docker --version || echo 'docker not found')"
if docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin available: $(docker compose version)"
else
  docker compose version || true
fi

echo "\n==> DONE — Server prepared."
echo "Note: If you were added to the docker group, re-login or run: 'newgrp docker' to pick up the change."
```

---

# B. Configuration file templates

Below are ready-to-copy templates. Place them at the repository root and customize `.env` from `.env.example` before deploying.

## 1) `docker-compose.yml`

```yaml
# docker-compose.yml
version: '3.9'

services:
  postgres:
    image: postgres:15
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n-net

  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    depends_on:
      - postgres
    env_file:
      - ./.env
    environment:
      # Minimal required variables are loaded from .env — kept here for clarity.
      - DB_TYPE=${DB_TYPE}
      - DB_POSTGRESDB_HOST=${POSTGRES_HOST}
      - DB_POSTGRESDB_PORT=${POSTGRES_PORT}
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      # Let n8n trust upstream proxy headers from Caddy
      - N8N_TRUSTED_HOSTS=*
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
    ports:
      - "5678:5678" # Expose to host for local/IP testing as requested
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-net

  caddy:
    image: caddy:2
    restart: unless-stopped
    depends_on:
      - n8n
    env_file:
      - ./.env
    environment:
      - DOMAIN_NAME=${DOMAIN_NAME}
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy_data:/data
      - caddy_config:/config
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
    networks:
      - n8n-net

volumes:
  postgres_data:
  n8n_data:
  caddy_data:
  caddy_config:

networks:
  n8n-net:
    driver: bridge
```

> Notes:
>
> * `n8n` maps host port `5678` to container port `5678` for local testing via IP.
> * `.env` is used for sensitive settings.

## 2) `.env.example`

```ini
# .env.example — copy to .env and edit values before deployment

# Postgres credentials
POSTGRES_USER=your_pg_user
POSTGRES_PASSWORD=very_secure_password_here
POSTGRES_DB=n8n_database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# n8n DB config
DB_TYPE=postgres
# The compose file references DB_POSTGRESDB_HOST etc. Keep POSTGRES_HOST consistent.

# n8n basic auth — enable for a first-line of protection (true/false)
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=change_this_strong_password

# Public domain used by Caddy for TLS and by n8n for webhook URLs
DOMAIN_NAME=example.com
WEBHOOK_URL=https://example.com/

# Timezone for n8n
GENERIC_TIMEZONE=UTC

# Helpful note: If you want to test via IP:5678 temporarily, use http://<vm-ip>:5678
```

> **Important:** Copy `.env.example` to `.env` and populate real secrets before running `02_deploy_stack.sh`.

## 3) `Caddyfile`

This `Caddyfile` uses an environment variable to define the domain. Caddyfile supports environment placeholders. We use `{$DOMAIN_NAME}` which Caddy will substitute from the environment when launching.

```caddyfile
# Caddyfile — uses environment variable DOMAIN_NAME

{$DOMAIN_NAME} {
  encode gzip

  # Proxy to internal n8n instance
  reverse_proxy n8n:5678 {
    header_up Host {host}
    header_up X-Real-IP {remote}
    header_up X-Forwarded-Proto {scheme}
    header_up X-Forwarded-For {remote}
  }

  # Optional: increase timeouts for long-running webhooks / executions
  @longReq {
    path /webhook/*
  }
}

# Localhost fallback (optional) — prevents Caddy from refusing to start if DOMAIN_NAME is empty
:80 {
  respond "No domain configured. Please set DOMAIN_NAME in your .env" 503
}
```

> Note: The `docker-compose.yml` mounts this `Caddyfile` into `/etc/caddy/Caddyfile`. Caddy will automatically obtain certificates for the hostname provided by `DOMAIN_NAME` at container start (assuming the domain points to your server's public IP).

---

# C. `02_deploy_stack.sh` — Deployment script

Save this file as `02_deploy_stack.sh` and make executable (`chmod +x 02_deploy_stack.sh`). It performs checks and runs `docker compose up -d` in a robust way.

```bash
#!/usr/bin/env bash
set -euo pipefail

# 02_deploy_stack.sh
# Deploy or restart the n8n stack via docker compose.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

# 1) Ensure .env exists
if [ ! -f "${ROOT_DIR}/.env" ]; then
  echo "ERROR: .env not found in ${ROOT_DIR}."
  echo "Please copy .env.example -> .env and fill in required values (POSTGRES_*, N8N_BASIC_AUTH_*, DOMAIN_NAME, WEBHOOK_URL, etc)."
  exit 1
fi

# 2) Source .env safely to obtain DOMAIN_NAME if needed
set -a
# shellcheck disable=SC1091
. "${ROOT_DIR}/.env"
set +a

# 3) Check DOMAIN_NAME is set (Caddy needs it)
if [ -z "${DOMAIN_NAME:-}" ]; then
  echo "WARNING: DOMAIN_NAME is not set in .env or environment."
  echo "Caddy will not be able to obtain certificates without a public domain pointing to this server."
  read -p "Continue anyway for local/IP testing? (y/N): " REPLY
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Aborting. Set DOMAIN_NAME in .env and re-run this script."
    exit 1
  fi
fi

# 4) Bring up the stack
# Use docker compose plugin command (modern) — this works both for initial deploy and restarts.

echo "==> Pulling images (if necessary) and starting stack..."
docker compose pull || true

echo "==> Starting containers with 'docker compose up -d'"
docker compose up -d --remove-orphans --build

# 5) Post-start checks
sleep 3

echo "==> Current container status:"
docker compose ps

echo "\n==> Deployment complete."

if [ -n "${DOMAIN_NAME:-}" ]; then
  echo "If DNS for ${DOMAIN_NAME} points to this server, Caddy will request certificates."
else
  echo "Caddy is configured but DOMAIN_NAME is not set. You can test n8n locally at: http://<server-ip>:5678"
fi

echo "To view logs: docker compose logs -f"
```

> This script supports both initial deploy and restarting the stack after a reboot. Containers will restart automatically if Docker is running (`restart: unless-stopped`).

---

# D. README / Usage (short)

1. Create the repo and copy these files to the repository root.
2. On a *fresh Ubuntu 25.04* VM, upload `01_prepare_server.sh`, then run:

```bash
sudo ./01_prepare_server.sh
```

3. Create `.env` from `.env.example` and fill in secrets and `DOMAIN_NAME` and `WEBHOOK_URL`.

```bash
cp .env.example .env
# Edit .env with your values
```

4. Deploy the stack:

```bash
./02_deploy_stack.sh
```

5. Test locally (before DNS changes):

* Visit `http://<vm-ip>:5678` for the n8n UI (basic auth may be active if configured in `.env`).
* When the domain in `.env` is pointed to the server's public IP, Caddy will automatically obtain TLS certs and proxy HTTPS traffic to n8n.

6. To update / upgrade images in future:

```bash
docker compose pull
docker compose up -d --remove-orphans --build
```

---

# E. Security & operational notes

* **Basic auth:** Keep `N8N_BASIC_AUTH_ACTIVE=true` until you configure proper authentication (OAuth / SSO / proxy auth). Basic auth reduces risk while testing.
* **Production considerations:** Consider adding:

  * Backups of the `postgres_data` and `n8n_data` volumes (e.g. `pg_dump`, filesystem snap + offsite storage).
  * Monitoring & logs (Prometheus/Grafana, or third-party). n8n offers telemetry/metrics.
  * A separate DB user with limited privileges, not `postgres` superuser.
  * Rate-limiting and stricter firewall rules when not actively testing via IP.
* **Let’s Encrypt:** Caddy handles ACME automatically. Ensure port 80 and 443 are public and DNS is set correctly.

---

# F. Example `.gitignore`

```
.env
*.pem
*.key
node_modules/
.DS_Store
```

---

# G. License

A short permissive license is recommended (MIT). Add a `LICENSE` file if you plan to publish the repo.

---

## Final checklist before first run

* [ ] Copy `.env.example` -> `.env` and fill in all placeholders.
* [ ] Ensure your domain DNS A/AAAA record points to the server (if you want public HTTPS right away).
* [ ] Run `01_prepare_server.sh` on Ubuntu 25.04 as root/sudo.
* [ ] Run `02_deploy_stack.sh` from repo root.

---

If you'd like, I can also:

* Provide a `systemd` unit for auto-starting the repo directory on boot (not necessary if Docker is enabled and restart policies are set),
* Create the exact `README.md` content (this file is easily used as-is),
* Add a simple `Makefile` to wrap common tasks.

<!-- End of document -->
