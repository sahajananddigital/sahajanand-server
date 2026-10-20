# Hetzner ARM64 Infrastructure as Code (IaC)

A lightweight, decoupled, Git-tracked Docker infrastructure designed for a **4GB RAM Hetzner ARM64 (aarch64)** server. Runs core shared services (Caddy reverse proxy, MariaDB, Redis) and application stacks with strict security boundaries, isolated networking, and memory budgeting.

---

## 1. Architecture Overview

This setup decouples the core platform services from individual application stacks using **external bridge networks**:

- `proxy_net`: External bridge network connecting Caddy to web applications. Only Caddy publishes public ports (`80`, `443`). No application container exposes raw host ports.
- `db_net`: External bridge network isolating shared databases (`shared_mariadb`, `shared_redis`). Applications that require database access join this network, while purely frontend/stateless apps never have access to it.

```
                          [ Public Internet ]
                                   │
                           Ports 80 / 443 / 443(udp)
                                   ▼
                         ┌───────────────────┐
                         │   caddy (proxy)   │ (mem_limit: 128MB)
                         └─────────┬─────────┘
                                   │
              ┌────────────────────┼─────────────────────────┐
              │               proxy_net                      │
              ▼                    ▼                    ▼    ▼
   ┌─────────────────────┐┌─────────────────┐┌───────────────┐┌─────────────────┐
   │    gitea (app)      ││ uptime_kuma(app)││  openwa (app) ││invoiceninja(app)│
   │  (mem_limit: 350MB) ││(mem_limit:256MB)││(mem_limit:512)││(mem_limit:512M) │
   └──────────┬──────────┘└─────────────────┘└───────────────┘└────────┬────────┘
              │                                                        │
              │                      db_net                            │
              └───────────┬────────────────────────────────────────────┘
                          ▼                 ▼
               ┌─────────────────────┐  ┌─────────────────────┐
               │   shared_mariadb    │  │    shared_redis     │
               │ (mem_limit: 512MB)  │  │ (mem_limit: 150MB)  │
               └─────────────────────┘  └─────────────────────┘
```

### Memory Budget (4GB RAM VPS)

| Service | Target Limit | Description |
| :--- | :--- | :--- |
| **Caddy** | `128MB` | Automatic TLS reverse proxy (HTTP/2 & HTTP/3) |
| **Shared MariaDB 11** | `512MB` | Tuned (`innodb_buffer_pool_size=256M`, `max_connections=100`) |
| **Shared Redis 7** | `150MB` | LRU cache (`maxmemory 128mb`) |
| **Gitea** | `350MB` | Lightweight Git service |
| **Uptime Kuma 2** | `256MB` | Monitoring dashboard |
| **OpenWA** | `512MB` | WhatsApp REST API gateway & web dashboard |
| **Invoice Ninja** | `512MB` | Open-source invoicing, billing & payments on shared MariaDB + Redis |
| **FreeScout** | `350MB` | Lightweight help desk & shared mailbox on shared MariaDB |
| **Host OS & Buffers** | `~1.5GB` | Kernel, page cache, headroom for new apps |

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
1. Edit the core infrastructure environment file and set a strong database root password:
   ```bash
   nano core-infra/.env
   ```
2. In Cloudflare DNS, add a wildcard record: **Type `A`**, **Name `*.app`**, pointing to your Hetzner server IP, set to **DNS only (Grey Cloud)**. This covers all apps under `*.app.sahajananddigital.in` without touching your main website (`sahajananddigital.in`).
3. Core routing is preconfigured in `core-infra/Caddyfile` for `git.app.sahajananddigital.in`, `status.app.sahajananddigital.in`, and `wa.app.sahajananddigital.in`.

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
Use `scripts/create-db.sh` to create an isolated database and user on `shared_mariadb`:
```bash
# Syntax: ./scripts/create-db.sh <app_name> <db_password>
./scripts/create-db.sh gitea "GenerateStrongPasswordHere"
```
The script creates database `gitea`, user `gitea`@`%`, and grants all necessary database privileges.

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

### Step 4: Start OpenWA (WhatsApp API Gateway & Dashboard)
OpenWA provides a WhatsApp REST API gateway and a built-in web management dashboard. It uses embedded SQLite storage and local media persistence:

```bash
cd apps/openwa
docker compose up -d
```

#### Files Structure
- **`apps/openwa/docker-compose.yml`**:
  - Image: `rmyndharis/openwa:latest` (Multi-arch native ARM64 & AMD64).
  - Storage: Persistent SQLite database & media files on named volume `openwa_data:/app/data`.
  - Network: Connected to external bridge `proxy_net` (no host ports exposed).
  - Limits: `mem_limit: 512m`, `shm_size: 256m` (for headless browser stability).
  - Plain-HTTP Dashboard Compatibility: `CSP_UPGRADE_INSECURE_REQUESTS=false` for local `*.localhost` access.
- **`apps/openwa/.env.example`**: Declares `OPENWA_DOMAIN=wa.example.com`.
- **`core-infra/Caddyfile`**: Configured with reverse proxy blocks for `wa.example.com`, `wa.localhost`, and `http://wa.localhost` pointing to `openwa:2785`.

#### Admin API Key
On its initial startup, OpenWA generates a secure admin API key and saves it to the persistent data volume. Retrieve it at any time with:
```bash
docker exec openwa cat /app/data/.api-key
```

#### How to Access OpenWA Locally

| Interface | Local URL |
| :--- | :--- |
| **Web Dashboard** | [http://wa.localhost](http://wa.localhost) |
| **Swagger REST API Docs** | [http://wa.localhost/api/docs](http://wa.localhost/api/docs) |
| **Direct REST API** | [http://wa.localhost/api](http://wa.localhost/api) |

#### How to Link Your WhatsApp Account
1. Open [http://wa.localhost](http://wa.localhost) in your browser.
2. Enter the admin API key retrieved above to log in to the dashboard.
3. Create/select a session and scan the QR code with WhatsApp (`Settings` > `Linked devices` > `Link a device`).

### Step 5: Start Invoice Ninja (Invoicing & Billing Connected to Shared MariaDB & Redis)
[Invoice Ninja](https://invoiceninja.com/) is a leading open-source platform for invoicing, payments, quotes, expenses, and client management. It connects directly to `shared_mariadb` across `db_net` and utilizes `shared_redis` for asynchronous job queues, cache, and session management:

#### Files Structure & Architecture
- **`apps/invoiceninja/docker-compose.yml`**:
  - Image (App): `invoiceninja/invoiceninja-debian:latest` (Official Debian image with built-in Chromium for SnapPDF on ARM64 and AMD64).
  - Image (Server): `nginx:alpine` (Lightweight web server routing static files and proxying PHP-FPM to `invoiceninja_app:9000`).
  - Storage:
    - `invoiceninja_public:/var/www/html/public`: Shared public assets between Nginx and PHP-FPM.
    - `invoiceninja_storage:/var/www/html/storage`: Persistent volume for generated PDF invoices, company logos, customer attachments, and audit logs.
  - Networks:
    - `proxy_net`: External bridge connecting `invoiceninja_server` to Caddy (no raw host ports exposed).
    - `db_net`: External bridge connecting `invoiceninja_app` to `shared_mariadb` and `shared_redis`.
    - `ninja_net`: Isolated internal bridge connecting `invoiceninja_server` to `invoiceninja_app:9000`.
  - Limits: `mem_limit: 512m` for app, `mem_limit: 64m` for Nginx server.
- **`apps/invoiceninja/in-vhost.conf`**: Nginx virtual host configuration routing requests to PHP-FPM and serving `/public`.
- **`apps/invoiceninja/.env.example`**: Template declaring database credentials, Redis connection, and admin setup.
- **`core-infra/Caddyfile`**: Configured with reverse proxy block routing `erp.app.sahajananddigital.in`, `invoice.app.sahajananddigital.in`, `erp.localhost`, and `invoice.localhost` to `invoiceninja_server:80`.

#### Step-by-Step Setup Instructions

1. **Provision isolated database and user on `shared_mariadb`**:
   ```bash
   ./scripts/create-db.sh invoiceninja "YourSecureNinjaPassword"
   ```
2. **Generate encryption key (`APP_KEY`)**:
   ```bash
   echo "base64:$(openssl rand -base64 32)"
   ```
3. **Configure environment**:
   ```bash
   cp apps/invoiceninja/.env.example apps/invoiceninja/.env # If not already created by init-server.sh
   nano apps/invoiceninja/.env
   ```
   Set `APP_KEY` with the generated string and ensure `DB_PASSWORD` matches the password from Step 1.
4. **Launch the stack**:
   ```bash
   cd apps/invoiceninja
   docker compose up -d
   ```
5. **Initial Migration & Auto-Provisioning**:
   Invoice Ninja automatically creates database schemas, seeds default settings, and configures the initial administrator account. You can follow progress with:
   ```bash
   docker logs -f --tail 50 invoiceninja_app
   ```

#### Access & Authentication

| Interface | URL | Default Credentials |
| :--- | :--- | :--- |
| **Local Environment** | [http://erp.localhost](http://erp.localhost) or [http://invoice.localhost](http://invoice.localhost) | Username: `admin@sahajananddigital.in` / Password: configured in `.env` |
| **Production Environment** | `https://erp.app.sahajananddigital.in` or `https://invoice.app.sahajananddigital.in` | Username: `admin@sahajananddigital.in` / Password: configured in `.env` |

#### Migrating Data from Frappe Books
A dedicated migration script [`scripts/migrate_frappe_to_invoiceninja.py`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/migrate_frappe_to_invoiceninja.py) seamlessly migrates:
- **Company Profile & Logo**: High-res logo, company address, PAN, UDYAM, GSTIN (URP), currency (`INR`), and India country settings.
- **Invoice Templates & Bank Footers**: Tamilnad Mercantile Bank & Federal Bank (Jupiter) payment details, UPI QR/handles, IFSC, and GST exemption declaration.
- **Products & Services**: Service items (Consultancy, Hosting, Domains, etc.).
- **Clients & Contacts**: 26 clients with full billing addresses, emails, phone numbers, and GSTINs.
- **Sales Invoices & Descriptions**: 46 historic invoices with exact numbering (`SINV-xxxx`), issue dates, line items, and rich service descriptions / terms.
- **Payments**: 45 payments linked to corresponding invoices with UTR reference numbers and balances updated.
- **Journal Entry Operating Expenses**: 89 expense records (totalling exact ₹222,512.12 across 88 operational journal entries) categorized across 20 expense categories and 26 vendors with payment dates and transaction references. Opening asset entries (`JV-1004`) are excluded from operational expenses.
- **Bank Accounts & Live Balances**: 4 accounts configured in Invoice Ninja Banking (`Tamilnad Mercantile Bank` ₹38,036.72, `Federal Bank` -₹9,788.29, `ICICI Bank` ₹2,550.00, and `Cash in Hand` ₹2,960.00).

To run or re-run the complete migration:
```bash
python3 scripts/migrate_frappe_to_invoiceninja.py
```

#### Exporting & Importing to Production

To migrate your complete Invoice Ninja instance (all 46 invoices, 45 payments, 26 clients, 89 expenses, 4 bank accounts, company logo, and templates) to your production server:

1. **Generate the Standalone Production Bundle**:
   ```bash
   ./scripts/backup-invoiceninja-production.sh
   ```
   This generates `backups/invoiceninja-production-backup_<timestamp>.tar.gz` and automatically uploads it to Google Drive at `gdrive:sahajanandserver/backups/invoiceninja/`.

2. **Import on the Production Server**:
   Transfer or download the backup bundle onto your production server, then run:
   ```bash
   # Option A: Using the repository restore script (Recommended)
   ./scripts/restore-invoiceninja.sh invoiceninja-production-backup_<timestamp>.tar.gz --domain https://erp.app.sahajananddigital.in

   # Option B: Extract and run the bundled self-contained installer
   tar -xzf invoiceninja-production-backup_<timestamp>.tar.gz
   cd invoiceninja-production-backup_<timestamp>
   ./import.sh --domain https://erp.app.sahajananddigital.in
   ```
   > [!IMPORTANT]
   > Your production `apps/invoiceninja/.env` **must** use the same `APP_KEY` from the backup (`base64:ah3XLtKHfr2u7PFoYnhal3W5hVMpK1ji+l2ZjFMBY7A=`), otherwise encrypted tokens and database entries cannot be decrypted. A ready-to-use template `production.env.example` is included inside the backup bundle.

#### Backing Up & Upgrading Invoice Ninja
- **Automated Backup to Rclone**:
  ```bash
  # Run the automated backup script to dump DB and storage, uploading to Google Drive:
  ./scripts/backup-rclone.sh
  ```
- **Manual Quick Backup**:
  ```bash
  # 1. Backup MariaDB database
  docker exec -t shared_mariadb mariadb-dump -u root -p"<root_password>" invoiceninja | gzip > ~/backups/invoiceninja_db_$(date +%Y%m%d).sql.gz

  # 2. Backup persistent storage (PDFs, templates, uploads, company logos)
  docker run --rm -v invoiceninja_invoiceninja_storage:/data -v ~/backups:/backup alpine tar czf /backup/invoiceninja_storage_$(date +%Y%m%d).tar.gz -C /data .
  ```
- **Zero-Friction Upgrades**:
  ```bash
  cd apps/invoiceninja
  docker compose pull
  docker compose up -d
  ```

### Step 5: Configure & Start FreeScout (Help Desk & Shared Inbox)

FreeScout is a lightweight, open-source help desk and shared inbox (Zendesk / Help Scout alternative) powered by PHP, Nginx, and MariaDB.

1. **Provision FreeScout database on `shared_mariadb`**:
   ```bash
   ./scripts/create-db.sh freescout "YourSecureFreeScoutDbPassword"
   ```
2. **Configure environment**:
   ```bash
   cp apps/freescout/.env.example apps/freescout/.env
   nano apps/freescout/.env
   ```
   Set `DB_PASS` to the password generated in step 1, configure `APP_URL`, and set `ADMIN_EMAIL` / `ADMIN_PASS`.
3. **Launch the stack**:
   ```bash
   cd apps/freescout
   docker compose up -d
   ```
4. **Follow initialization**:
   ```bash
   docker logs -f freescout
   ```

#### Access & Authentication

| Interface | URL | Default Credentials |
| :--- | :--- | :--- |
| **Local Environment** | [http://help.localhost](http://help.localhost) | Username: `admin@sahajananddigital.in` / Password: configured in `.env` |
| **Production Environment** | `https://help.app.sahajananddigital.in` | Username: `admin@sahajananddigital.in` / Password: configured in `.env` |

### Local Testing URLs
When running locally on Docker Desktop, macOS and all modern browsers resolve any `*.localhost` domain to `127.0.0.1` automatically without editing `/etc/hosts`:
- **Gitea**: [http://git.localhost](http://git.localhost)
- **Uptime Kuma**: [http://status.localhost](http://status.localhost)
- **OpenWA**: [http://wa.localhost](http://wa.localhost)
- **Invoice Ninja**: [http://erp.localhost](http://erp.localhost) or [http://invoice.localhost](http://invoice.localhost)
- **FreeScout**: [http://help.localhost](http://help.localhost)

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

## 5. Automated Offsite Backups via Rclone (Google Drive)

A comprehensive backup script [`scripts/backup-rclone.sh`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/backup-rclone.sh) is provided to back up all databases, Invoice Ninja persistent storage, application states, and server configuration files, bundle them into a compressed archive, upload them to offsite cloud storage via **Rclone** (`gdrive:sahajanandserver/backups`), and prune stale backups automatically according to a configurable retention policy.

### What Gets Backed Up
1. **MariaDB Databases**:
   - `database/invoiceninja_<timestamp>.sql.gz`: Dedicated single-transaction gzip dump of the `invoiceninja` database.
   - `database/all_databases_<timestamp>.sql.gz`: Full dump of all databases across the MariaDB instance (`invoiceninja`, `gitea`, `mysql`, etc.).
2. **Invoice Ninja Storage**:
   - `storage/invoiceninja_storage_<timestamp>.tar.gz`: Persistent files, company logos, documents, and invoice PDFs from `/var/www/html/storage` (excluding ephemeral framework caches, views, and session data).
3. **Application Configurations & Scripts**:
   - `configs/server_configs_<timestamp>.tar.gz`: All `.env` environment files, `docker-compose.yml` definitions, `Caddyfile`, Nginx vhost configs, and deployment scripts (`scripts/`).
4. **Platform & Application States**:
   - `storage/caddy_tls_data_<timestamp>.tar.gz`: Caddy Let's Encrypt / ZeroSSL TLS certificates and account keys.
   - `storage/gitea_data_<timestamp>.tar.gz`: Git repositories, SSH host keys, and user assets.
   - `storage/uptime_kuma_data_<timestamp>.tar.gz`: Uptime Kuma monitoring database and history.
   - `storage/openwa_data_<timestamp>.tar.gz`: WhatsApp web session data and tokens (skippable with `--skip-openwa`).
5. **Manifest & Bundle**:
   - Generates `manifest.txt` with container versions, checksums, and execution timestamps.
   - Bundles everything into a single timestamped archive: `sahajanand-backup_<YYYY-MM-DD_HH-MM-SS>.tar.gz`.

### Usage Commands

```bash
# Standard backup (Backs up all databases, Invoice Ninja, configs, and uploads to Google Drive)
./scripts/backup-rclone.sh

# Fast backup (Skips large OpenWA session files)
./scripts/backup-rclone.sh --skip-openwa

# Database-only backup
./scripts/backup-rclone.sh --db-only

# Dry-run test (Creates local bundle in ./backups/ without uploading to Google Drive)
./scripts/backup-rclone.sh --dry-run

# Custom retention (e.g. keep 14 days of backups on remote instead of default 7)
./scripts/backup-rclone.sh --retention 14

# Keep a local copy in ./backups/ in addition to uploading to Google Drive
./scripts/backup-rclone.sh --keep-local
```

### Scheduling Automated Daily Backups with Cron

To run the backup automatically every night at 02:00 AM UTC and log the output:

```bash
# Edit the host crontab
crontab -e
```

Add the following cron entry (adjust path to your repo location, e.g. `/opt/infrastructure`):
```cron
# Daily backup at 2:00 AM UTC with 7-day retention
0 2 * * * /opt/infrastructure/scripts/backup-rclone.sh --skip-openwa >> /var/log/sahajanand-backup.log 2>&1
```

### Disaster Recovery & Restoration

To restore any database or storage from an archive:

```bash
# 1. Download or extract the backup bundle
tar -xzf sahajanand-backup_<timestamp>.tar.gz
cd sahajanand_backup_<timestamp>

# 2. Restore Invoice Ninja database
gunzip -c database/invoiceninja_<timestamp>.sql.gz | docker exec -i shared_mariadb mariadb -u root -p"<root_password>" invoiceninja

# 3. Restore all databases
gunzip -c database/all_databases_<timestamp>.sql.gz | docker exec -i shared_mariadb mariadb -u root -p"<root_password>"

# 4. Restore Invoice Ninja persistent storage (logos, PDFs, uploads)
docker exec -i invoiceninja_app tar -xzf - -C /var/www/html/storage < storage/invoiceninja_storage_<timestamp>.tar.gz

# 5. Clear Invoice Ninja cache
docker exec -it invoiceninja_app php artisan optimize:clear
```

---

## 6. Zero-Downtime Caddy Reload

Whenever you modify `core-infra/Caddyfile` (e.g., adding routes, updating headers), **never restart Caddy**. Reload it dynamically with zero downtime using [`scripts/reload-caddy.sh`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/reload-caddy.sh):

```bash
# Safely validate syntax and reload Caddy with zero downtime
./scripts/reload-caddy.sh

# Validate syntax only without reloading (dry-run pre-flight check)
./scripts/reload-caddy.sh --check

# Stream recent Caddy reverse proxy and operational logs
./scripts/reload-caddy.sh --logs

# Inspect active Let's Encrypt certificates and expiry dates
./scripts/reload-caddy.sh --certs
```

The script automatically executes `caddy validate` inside the container first. If a syntax error is detected, reload is aborted and the exact error is displayed, preventing any disruption to live production traffic.

---

## 7. Safe Production Maintenance & Git Workflow

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

---

## 8. Useful Administration & Operational Commands

A quick reference cheat sheet for maintaining and administering this Docker infrastructure on a 4GB RAM VPS.

### 8.1 Essential Management & Automation Scripts

| Script | Purpose | Example Usage |
| :--- | :--- | :--- |
| [`scripts/reload-caddy.sh`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/reload-caddy.sh) | Zero-downtime Caddy reload with pre-flight syntax validation | `./scripts/reload-caddy.sh` |
| [`scripts/server-status.sh`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/server-status.sh) | Health dashboard (host RAM, disk, DB/Redis online check, container statuses) | `./scripts/server-status.sh` |
| [`scripts/clean-docker.sh`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/clean-docker.sh) | Safe Docker disk space cleanup (reclaims build cache, dangling images) | `./scripts/clean-docker.sh --deep` |
| [`scripts/update-app.sh`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/update-app.sh) | Zero-downtime updates for any app stack or all stacks sequentially | `./scripts/update-app.sh freescout` |
| [`scripts/backup-rclone.sh`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/backup-rclone.sh) | Automated offsite Google Drive backups with retention management | `./scripts/backup-rclone.sh` |
| [`scripts/create-db.sh`](file:///Users/multidots/Documents/Github/sahajanand-server/scripts/create-db.sh) | Provision isolated MariaDB database & user | `./scripts/create-db.sh myapp "pass"` |

### 8.2 Service & Container Management

```bash
# View all running containers with status and ports
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Inspect live CPU and RAM consumption across all containers
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"

# Stream logs of any container in real-time
docker logs -f --tail 100 <container_name>

# Restart a specific service without affecting others
docker restart <container_name>

# Safely bring down a specific app stack while preserving persistent volumes
cd apps/<app_name> && docker compose down
```

### 8.3 MariaDB Operations (`shared_mariadb`)

```bash
# Open interactive MariaDB root SQL shell
docker exec -it shared_mariadb mariadb -u root -p

# Connect directly to a specific app database as the app user
docker exec -it shared_mariadb mariadb -u <app_user> -p <app_dbname>

# Check sizes of all databases on shared MariaDB
docker exec -it shared_mariadb mariadb -u root -p -e "
SELECT table_schema AS 'Database',
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES
GROUP BY table_schema;"

# Dump a single app database to a compressed archive
docker exec -t shared_mariadb mariadb-dump -u root -p"<root_password>" <dbname> | gzip > ~/backups/<dbname>_$(date +%Y%m%d_%H%M%S).sql.gz

# Dump all databases at once
docker exec -t shared_mariadb mariadb-dump -u root -p"<root_password>" --all-databases | gzip > ~/backups/all_dbs_$(date +%Y%m%d_%H%M%S).sql.gz

# Restore an app database from a compressed dump
gunzip < ~/backups/<dbname>_backup.sql.gz | docker exec -i shared_mariadb mariadb -u root -p"<root_password>" <dbname>

# Check active database queries and connections
docker exec -it shared_mariadb mariadbadmin -u root -p processlist
```

### 8.4 Caddy Reverse Proxy & TLS (`caddy`)

```bash
# Validate Caddyfile syntax and reload with zero downtime
./scripts/reload-caddy.sh

# Stream live HTTP access and reverse proxy routing logs
docker logs -f --tail 100 caddy

# Inspect active Let's Encrypt certificates stored by Caddy
./scripts/reload-caddy.sh --certs
```

### 8.5 Redis Cache Operations (`shared_redis`)

```bash
# Open interactive Redis CLI
docker exec -it shared_redis redis-cli

# View Redis memory statistics and hit rates
docker exec -it shared_redis redis-cli info memory
docker exec -it shared_redis redis-cli info stats

# Flush cache database (Emergency cache clear only)
docker exec -it shared_redis redis-cli flushdb
```

### 8.6 Application-Specific CLI Cheat Sheet

#### FreeScout (`freescout`)
```bash
# View FreeScout container and PHP-FPM logs
docker logs --tail 100 freescout

# Run Artisan maintenance commands
docker exec -it freescout php artisan freescout:clear-cache
docker exec -it freescout php artisan freescout:check-app

# Inspect persistent storage directory (attachments, modules, uploads)
docker exec freescout ls -la /data
```

#### Invoice Ninja (`invoiceninja_app`)
```bash
# View application and PHP worker logs
docker logs --tail 100 invoiceninja_app

# Run Artisan maintenance commands
docker exec -it invoiceninja_app php artisan optimize:clear
docker exec -it invoiceninja_app php artisan ninja:check-data

# Inspect persistent storage directory
docker exec invoiceninja_app ls -la /var/www/html/storage

# Open interactive bash shell
docker exec -it invoiceninja_app bash
```

#### Gitea (`gitea`)
```bash
# List all registered Gitea accounts
docker exec -it -u 1000 gitea gitea admin user list

# Create a new administrator account from CLI
docker exec -it -u 1000 gitea gitea admin user create --username <username> --password "<password>" --email <email> --admin

# Regenerate Git hooks for all repositories
docker exec -it -u 1000 gitea gitea admin regenerate hooks
```

#### OpenWA WhatsApp Gateway (`openwa`)
```bash
# Retrieve the admin API key for the dashboard and REST API
docker exec openwa cat /app/data/.api-key

# Inspect active session data and media files
docker exec openwa ls -la /app/data

# Restart the WhatsApp gateway session cleanly
docker restart openwa
```

#### Uptime Kuma (`uptime_kuma`)
```bash
# Reset Uptime Kuma administrator credentials or 2FA via emergency helper
docker exec -it uptime_kuma node extra/reset-password.js
```

### 8.7 Host VPS Maintenance & Disk Pruning

On a 4GB RAM VPS with limited SSD storage (e.g. 40GB–80GB), dangling container images and build caches can gradually fill the disk. Use the safe automated cleanup script:

```bash
# Safely prune build caches, dangling layers, and stopped containers
./scripts/clean-docker.sh

# Deep clean: also prune unused images older than 7 days (168 hours)
./scripts/clean-docker.sh --deep

# Check system health dashboard
./scripts/server-status.sh
```
