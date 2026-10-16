# Hetzner ARM64 Infrastructure as Code (IaC)

A lightweight, decoupled, Git-tracked Docker infrastructure designed for a **4GB RAM Hetzner ARM64 (aarch64)** server. Runs core shared services (Caddy reverse proxy, PostgreSQL, Redis) and application stacks with strict security boundaries, isolated networking, and memory budgeting.

---

## 1. Architecture Overview

This setup decouples the core platform services from individual application stacks using **external bridge networks**:

- `proxy_net`: External bridge network connecting Caddy to web applications. Only Caddy publishes public ports (`80`, `443`). No application container exposes raw host ports.
- `db_net`: External bridge network isolating shared databases (`shared_postgres`, `shared_redis`). Applications that require database access join this network, while purely frontend/stateless apps never have access to it.

```
                          [ Public Internet ]
                                   │
                           Ports 80 / 443 / 443(udp)
                                   ▼
                         ┌───────────────────┐
                         │   caddy (proxy)   │ (mem_limit: 128MB)
                         └─────────┬─────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │               proxy_net                 │
              ▼                                         ▼
   ┌─────────────────────┐                   ┌─────────────────────┐
   │    gitea (app)      │                   │ uptime_kuma (app)   │
   │  (mem_limit: 350MB) │                   │ (mem_limit: 256MB)  │
   └──────────┬──────────┘                   └─────────────────────┘
              │
              │                 db_net
              └───────────┬─────────────────┐
                          ▼                 ▼
               ┌─────────────────────┐  ┌─────────────────────┐
               │   shared_postgres   │  │    shared_redis     │
               │ (mem_limit: 512MB)  │  │ (mem_limit: 150MB)  │
               └─────────────────────┘  └─────────────────────┘
```

### Memory Budget (4GB RAM VPS)

| Service | Target Limit | Description |
| :--- | :--- | :--- |
| **Caddy** | `128MB` | Automatic TLS reverse proxy (HTTP/2 & HTTP/3) |
| **Shared PostgreSQL 16** | `512MB` | Tuned (`shared_buffers=256MB`, `work_mem=8MB`) |
| **Shared Redis 7** | `150MB` | LRU cache (`maxmemory 128mb`) |
| **Gitea** | `350MB` | Lightweight Git service |
| **Uptime Kuma** | `256MB` | Monitoring dashboard |
| **Host OS & Buffers** | `~2.6GB` | Kernel, page cache, headroom for new apps |

---

## 2. Initial Server Setup

### Step 1: Clone Repository
On your Hetzner VPS:
```bash
git clone https://github.com/<your-username>/<your-repo>.git /opt/infrastructure
cd /opt/infrastructure
```

### Step 2: Initialize Server Networks & Configs
Run the initialization script. It creates `proxy_net` and `db_net` (if they do not already exist) and copies `.env.example` templates to `.env`:
```bash
./scripts/init-server.sh
```

### Step 3: Configure Core Environment & DNS
1. Edit the core infrastructure environment file and set a strong database password:
   ```bash
   nano core-infra/.env
   ```
2. Update DNS A/AAAA records for your domains (e.g., `git.example.com`, `status.example.com`) pointing to your Hetzner server IP.
3. Edit `core-infra/Caddyfile` with your actual domain names and administrative email.

### Step 4: Start Core Infrastructure
```bash
cd core-infra
docker compose up -d
```
Verify all core services are running and healthy:
```bash
docker compose ps
```

---

## 3. Provisioning App Databases & Starting Stacks

### Step 1: Provision an Isolated Database
Use `scripts/create-db.sh` to create an isolated database and role on `shared_postgres`:
```bash
# Syntax: ./scripts/create-db.sh <app_name> <db_password>
./scripts/create-db.sh gitea "GenerateStrongPasswordHere"
```
The script creates role `gitea`, database `gitea`, and grants all necessary schema privileges.

### Step 2: Configure & Start Gitea
1. Update `apps/gitea/.env` with the database password set above:
   ```bash
   nano apps/gitea/.env
   ```
2. Launch the Gitea container:
   ```bash
   cd apps/gitea
   docker compose up -d
   ```

### Step 3: Start Uptime Kuma
Uptime Kuma requires no database setup as it uses its own embedded storage on a named volume:
```bash
cd apps/uptime-kuma
docker compose up -d
```

---

## 4. How to Add a New App Stack

To add any new application (e.g., `nextcloud`, `vaultwarden`, `plausible`):

1. **Create directory**:
   ```bash
   mkdir -p apps/my-app
   ```
2. **Create `apps/my-app/docker-compose.yml`**:
   - Do **NOT** expose host `ports:`.
   - Connect to `proxy_net` (for web access) and `db_net` (if database is needed).
   - Define a memory limit (e.g., `mem_limit: 256m`).
3. **Provision database** (if needed):
   ```bash
   ./scripts/create-db.sh my_app "SecureAppDbPassword"
   ```
4. **Add reverse proxy block to `core-infra/Caddyfile`**:
   ```caddyfile
   app.example.com {
       encode zstd gzip
       reverse_proxy my_app:8080
   }
   ```
5. **Reload Caddy without downtime** (see below).
6. **Start the app**:
   ```bash
   cd apps/my-app && docker compose up -d
   ```

---

## 5. Zero-Downtime Caddy Reload

Whenever you modify `core-infra/Caddyfile` (e.g., adding routes, updating headers), **never restart Caddy**. Reload it dynamically with zero downtime:

```bash
docker exec -w /etc/caddy caddy caddy reload
```

Caddy validates the syntax before applying changes. If an error exists, the previous configuration remains active without dropping active connections.

---

## 6. Safe Production Maintenance & Git Workflow

### Pulling Updates Safely
Never edit tracked configuration files directly on the production host in a way that creates merge conflicts. Always use fast-forward pulls:

```bash
cd /opt/infrastructure
git fetch origin
git status
git pull --ff-only origin main
```

If `core-infra/Caddyfile` changed, reload Caddy:
```bash
docker exec -w /etc/caddy caddy caddy reload
```

If a compose file changed, redeploy that specific stack:
```bash
cd apps/<app_name>
docker compose pull
docker compose up -d
```

### Checking Memory Usage
Monitor your 4GB RAM utilization across all containers:
```bash
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
```

### Backing Up PostgreSQL Databases
Create compressed database dumps without taking down the server:
```bash
# Dump a single app database
docker exec -t shared_postgres pg_dump -U postgres gitea | gzip > ~/backups/gitea_$(date +%Y%m%d_%H%M%S).sql.gz

# Dump all databases
docker exec -t shared_postgres pg_dumpall -U postgres | gzip > ~/backups/all_dbs_$(date +%Y%m%d_%H%M%S).sql.gz
```
