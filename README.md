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

## Quick Start (Local Development)

### 1. Configure Environment (Optional)

```bash
cp .env.example .env
# Edit .env if you want to change MySQL passwords
```

### 2. Setup phpLiteAdmin (One-time)

```bash
cd phpliteadmin
./setup.sh
```

This downloads and configures phpLiteAdmin. **Don't forget to set a password** in `phpliteadmin.php`!

### 3. Start Infrastructure (Traefik + MySQL + Admin Tools)

```bash
docker-compose up -d
```

This starts Traefik, MySQL, phpMyAdmin, and phpLiteAdmin.

### 4. Add Host Entries (Local Development)

```bash
cd clients
./add-hosts.sh 127.0.0.1
```

### 5. Deploy a Client

```bash
cd clients/client1
docker-compose up -d --build
```

### 6. Access Admin Tools

- **phpMyAdmin:** `http://phpmyadmin.example.com` (Login: root / password from .env)
- **phpLiteAdmin:** `http://phpliteadmin.example.com` (Password set in phpliteadmin.php)

### 7. Test

Visit `http://client1.example.com` in your browser (or use curl with Host header)

## Production Deployment

See **[PRODUCTION.md](PRODUCTION.md)** for complete production deployment guide.

### Quick Production Setup

1. **Configure environment:**
   ```bash
   cp .env.example .env
   nano .env  # Set EMAIL=your-email@domain.com
   ```

2. **Start with production config:**
   ```bash
   docker-compose -f docker-compose.prod.yml --env-file .env up -d
   ```

3. **Update client domains** in each client's `docker-compose.yml`

4. **Deploy clients:**
   ```bash
   cd clients/client1
   # Update domain in docker-compose.yml
   docker-compose up -d --build
   ```

## Directory Structure

```
.
├── docker-compose.yml          # Local development config
├── docker-compose.prod.yml     # Production config
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

- **Local:** Uses `docker-compose.yml` and `traefik/traefik.yml`
  - HTTP works without SSL
  - Dashboard on port 8080
  
- **Production:** Uses `docker-compose.prod.yml` and `traefik/traefik.prod.yml`
  - Automatic HTTP to HTTPS redirect
  - Dashboard restricted to localhost
  - SSL certificates via Let's Encrypt

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

[Your License Here]

