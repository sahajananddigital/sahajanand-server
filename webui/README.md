# Web UI - Server Management Interface

Modern web-based management interface for Sahajanand Server Infrastructure.

## Features

- **Dashboard**: Overview of clients, containers, databases, and backups
- **Client Management**: View, start, stop, and restart client containers
- **Database Management**: Create, view, and manage MySQL databases
- **Backup Management**: Create backups, view backup history, restore, and download
- **System Status**: Monitor Docker containers, view logs, manage system resources

## Access

Access the Web UI via Traefik:
- **Local Development**: `http://webui.example.com`
- **Production**: `https://webui.yourdomain.com`

Add to `/etc/hosts` for local development:
```
127.0.0.1 webui.example.com
```

## Setup

The Web UI has its own docker-compose file for independent management.

### Local Development

1. **Start the main infrastructure first** (from project root):
   ```bash
   docker-compose up -d
   ```
   This starts Traefik and creates the `web` network.

2. **Start the Web UI** (from webui directory):
   ```bash
   cd webui
   docker-compose up -d --build
   ```

### Production

1. **Start the main infrastructure** (from project root):
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

2. **Start the Web UI** (from webui directory):
   ```bash
   cd webui
   docker-compose -f docker-compose.prod.yml up -d --build
   ```

### Quick Start (All Services)

From the project root, you can start everything:

```bash
# Local development
docker-compose up -d && cd webui && docker-compose up -d

# Production
docker-compose -f docker-compose.prod.yml up -d && cd webui && docker-compose -f docker-compose.prod.yml up -d
```

The Web UI container will:
- Build automatically from the Dockerfile
- Connect to the existing `web` network (created by main docker-compose)
- Access Docker socket for container management
- Access project files (clients, mysql scripts, backup script)

## Structure

```
webui/
├── public/          # Web-accessible files
│   ├── index.php    # Main entry point
│   └── api/         # API endpoints
├── includes/        # PHP includes
│   ├── config.php   # Configuration
│   ├── functions.php # Helper functions
│   ├── dashboard.php
│   ├── clients.php
│   ├── databases.php
│   ├── backups.php
│   └── system.php
└── Dockerfile       # Container definition
```

## API Endpoints

All API endpoints are in `/api/`:

- `POST /api/clients.php` - Client management (start, stop, restart)
- `POST /api/databases.php` - Database management (create, delete)
- `POST /api/backups.php` - Backup management (create, restore, delete)
- `GET /api/backups.php?action=download&path=...` - Download backup
- `POST /api/system.php` - Container management (start, stop, restart, logs)
- `GET /api/system.php?action=logs&container=...` - View container logs

## Security

⚠️ **CRITICAL**: The Web UI includes comprehensive security features:

### Authentication (Required)
**Before first use**, set up authentication:

```bash
cd webui
./setup-auth.sh
```

Or manually create `.webui_auth` in the project root:
```
WEBUI_USERNAME=admin
WEBUI_PASSWORD_HASH=$2y$10$...your-hash...
```

### Security Features

1. **Authentication System**: Login required for all pages and API endpoints
2. **CSRF Protection**: All forms and API calls protected against CSRF attacks
3. **Input Validation**: All user input validated and sanitized
4. **Brute Force Protection**: Rate limiting (5 attempts per 15 minutes)
5. **Security Headers**: XSS protection, frame options, content-type sniffing prevention
6. **Session Security**: HttpOnly, Secure cookies, IP validation
7. **Path Traversal Prevention**: All file operations validated
8. **Shell Injection Prevention**: All commands properly escaped

See **[SECURITY.md](SECURITY.md)** for complete security documentation and production checklist.

### Important Notes:

1. **Docker Socket Access**: The Web UI has full Docker socket access. This gives it significant privileges.
2. **Production Use**: 
   - ✅ Authentication is now required
   - Use HTTPS only (automatic with Traefik)
   - Consider IP whitelisting (see SECURITY.md)
   - Review logs regularly

3. **File Access**: The Web UI can read project files and execute scripts. Ensure proper file permissions.

## Adding Authentication

### Option 1: Traefik Basic Auth

Add to `traefik/dynamic.yml`:

```yaml
http:
  middlewares:
    webui-auth:
      basicAuth:
        users:
          - "admin:$2y$10$..." # Generate with: htpasswd -nb admin password | base64
```

Update `docker-compose.yml` webui labels:

```yaml
- "traefik.http.routers.webui.middlewares=security-headers@file,gzip@file,webui-auth@file"
```

### Option 2: Application-Level Auth

Add session management and login functionality to `index.php`.

## Troubleshooting

### Web UI not accessible

1. Check if container is running: `docker ps | grep webui`
2. Check Traefik logs: `docker logs traefik`
3. Verify hostname in `/etc/hosts` (local) or DNS (production)

### Docker commands not working

1. Check Docker socket mount: `docker exec webui ls -la /var/run/docker.sock`
2. Check permissions: The www-data user should be in docker group

### Scripts not executable

1. Ensure scripts are executable on host: `chmod +x backup.sh`
2. Check volume mounts in docker-compose.yml

## Development

To modify the Web UI:

1. Edit files in `webui/` directory
2. Changes are reflected immediately (volumes are mounted)
3. For container rebuild: `docker-compose up -d --build webui`

## Dependencies

The Web UI requires:
- PHP 8.2+
- Apache with mod_rewrite
- Docker CLI (for container management)
- zstd (for backup operations)
- Bash (for script execution)

All dependencies are included in the Dockerfile.

