# Sahajanand Server Infrastructure

Docker-based infrastructure setup with Traefik reverse proxy and PHP client containers.

## Features

- **Traefik v3** reverse proxy with automatic SSL (Let's Encrypt)
- **PHP 8.2-FPM** containers with Nginx for each client
- **Isolated client containers** - each client has its own folder and configuration
- **MySQL database** - each client has isolated database and credentials
- **SQLite support** - for each client
- **phpMyAdmin** - MySQL database administration tool
- **phpLiteAdmin** - SQLite database administration tool
- **Automatic HTTPS** in production
- **Security headers** and gzip compression

## Quick Start Guide

We have simplified the deployment workflow with automated setup wizards. Do not run these as the root user. If you are on a fresh VPS logged in as `root`, first run the user creation script to create a secure system admin:

```bash
bash create-admin-user.sh
```

Log in as the newly created system admin user to perform the installation.

### Automated Setup

Run the main setup script in your project directory:

```bash
bash setup.sh
```

The script will guide you through the configuration process:
1. **Choose Environment Mode**: Select `1` for Production (SSL certificates enabled, secure binds, automated restarts) or `2` for Local Development (HTTP only, exposed ports, no SSL).
2. **Configure Domain Routing**: Specify your base domain name and subdomains for the admin tools.
3. **Database & Web UI Passwords**: Auto-generates secure random credentials.
4. **Cloud Backup (Optional)**: Set up Google Drive or other remote backups via rclone.
5. **Start Infrastructure**: Automatically configures subvolumes, sets permissions, and starts Traefik, MySQL, phpMyAdmin, and the Web UI.

All generated passwords and access details will be printed on the screen and stored securely in `credentials.txt` (which has restricted permissions).

### Manual Setup (Advanced)

If you prefer to start services manually:
1. Copy the environment template: `cp .env.example .env` and update details.
2. Initialize phpLiteAdmin: `cd phpliteadmin && bash setup.sh`.
3. Create the database directory for Web UI: `mkdir -p webui/data && chmod 777 webui/data`.
4. Start core services: `docker compose up -d`.
5. Start Web UI: `docker compose -f webui/docker-compose.yml up -d --build`.

---

## Directory Structure

```
.
├── docker-compose.yml          # Unified Docker Compose config
├── traefik/
│   ├── traefik.yml            # Local Traefik config
│   ├── traefik.prod.yml       # Production Traefik config
│   └── dynamic.yml            # Dynamic middleware config
├── clients/
│   ├── client1/               # Client 1
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   ├── nginx.conf
│   │   └── [application files]
│   └── client2/               # Client 2 (add as needed)
├── mysql/
│   ├── init/                  # SQL initialization scripts
│   └── README.md              # MySQL documentation
├── ssl/                       # SSL certificates (gitignored)
├── logs/                      # Logs (gitignored)
└── .env                       # Environment variables (gitignored)
```

## Configuration

### Local Development vs Production

All services are declared in a single, unified `docker-compose.yml` file. Behaviors are toggled seamlessly via your `.env` file (which can be configured automatically using the root `setup.sh` script):

- **Local Development Mode (`setup.sh` option 2):**
  - Uses `traefik/traefik.yml` (HTTP only)
  - Traefik dashboard is exposed publicly on port `8080`
  - Container restart policies are disabled (`no`)
  - phpMyAdmin automatically logs in using credentials defined in `.env`
  
- **Production Mode (`setup.sh` option 1):**
  - Uses `traefik/traefik.prod.yml` (HTTPS enabled, automated Let's Encrypt SSL)
  - Traefik dashboard is locked down securely to `127.0.0.1:8080` (requires SSH tunneling)
  - Automatic container restarts are enabled (`unless-stopped`)
  - phpMyAdmin forces users to login manually for safety

### Adding a New Client

1. Copy `clients/client1/` to `clients/your-client-name/`
2. Update `docker-compose.yml`:
   - Change service name and container name
   - Update domain in Traefik labels
3. Deploy: `cd clients/your-client-name && docker-compose up -d --build`

See `clients/README.md` for detailed instructions.

## Environment Variables

Create `.env` file (see `.env.example`):

```bash
EMAIL=your-email@domain.com          # Required for SSL certificates
TRAEFIK_LOG_LEVEL=INFO              # Optional

# MySQL Configuration
MYSQL_ROOT_PASSWORD=rootpassword     # MySQL root password
MYSQL_DATABASE=app_db               # Default database name
MYSQL_USER=app_user                 # MySQL user for applications
MYSQL_PASSWORD=app_password         # MySQL user password
MYSQL_PORT=3306                     # MySQL port (default: 3306)
```

## SSL Certificates

- Automatically managed by Let's Encrypt
- Stored in `ssl/acme.json`
- Auto-renewed before expiration
- First certificate may take a few minutes to issue

## Troubleshooting

### Check Logs

```bash
# Traefik logs
docker logs traefik

# Client logs
docker logs client1

# File logs
tail -f logs/traefik/traefik.log
```

### Common Issues

1. **SSL certificate errors:** Check email in `.env` and DNS records
2. **404 errors:** Verify Traefik labels and container network
3. **Connection refused:** Check if containers are running: `docker ps`

## Database Support

### MySQL (Isolated Databases)

A shared MySQL container is available, but **each client has its own isolated database and credentials**:

**Host:** `mysql` (container name)  
**Port:** `3306`  
**Database:** `{client_name}_db` (e.g., `client1_db`)  
**Username:** `{client_name}_user` (e.g., `client1_user`)

```php
// Example for client1
$pdo = new PDO('mysql:host=mysql;dbname=client1_db', 'client1_user', 'client1_password');
```

**Security:** Each client can only access their own database. Data is completely isolated between clients.

**Adding a new client database:**
```bash
cd mysql
./add-client-db.sh client2
```

See **[mysql/README.md](mysql/README.md)** for detailed MySQL documentation.

### SQLite

Each client can use SQLite in their `database/` directory. See `clients/README.md` for details.

## Backups

Automated backup script with rclone integration and zstd compression.

**Quick Start:**
```bash
# Local backup only
./backup.sh

# Upload to rclone remote
./backup.sh myremote:backups/sahajanand-server
```

The backup script automatically:
- Discovers all clients
- Backs up each client's MySQL database separately
- Backs up each client's files (including SQLite databases)
- Compresses with zstd
- Organizes backups by client in separate directories

See **[BACKUP.md](BACKUP.md)** for complete backup documentation, including restore procedures and automation setup.

## Web UI Management Interface

Modern web-based interface for managing your entire infrastructure.

**Access:**
- Local: `http://webui.example.com`
- Production: `https://webui.yourdomain.com`

**Features:**
- Dashboard with system overview
- Client management (start, stop, restart containers)
- Database management (create, view MySQL databases)
- Backup management (create, restore, download backups)
- System status (container management, logs)

The Web UI is managed separately with its own docker-compose file. See [webui/README.md](webui/README.md) for setup instructions. Add `webui.example.com` to your `/etc/hosts` for local development.

See **[webui/README.md](webui/README.md)** for detailed documentation.

⚠️ **Security**: The Web UI includes comprehensive security features:
- **Authentication required** (set up with `webui/setup-auth.sh`)
- CSRF protection on all endpoints
- Input validation and sanitization
- Brute force protection
- Security headers

See **[webui/SECURITY.md](webui/SECURITY.md)** for complete security documentation.

**Note**: The Web UI has Docker socket access, so authentication is critical!

## Documentation

- **[PRODUCTION.md](PRODUCTION.md)** - Complete production deployment guide
- **[BACKUP.md](BACKUP.md)** - Backup and restore documentation
- **[webui/README.md](webui/README.md)** - Web UI management interface documentation
- **[ADMIN_TOOLS.md](ADMIN_TOOLS.md)** - phpMyAdmin and phpLiteAdmin documentation
- **[clients/README.md](clients/README.md)** - Client setup and configuration
- **[mysql/README.md](mysql/README.md)** - MySQL database documentation

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

