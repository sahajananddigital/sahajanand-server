# Admin Tools Documentation

This infrastructure includes two web-based database administration tools:

## phpMyAdmin - MySQL Administration

### Access

- **Local Development:** `http://phpmyadmin.example.com`
- **Production:** `https://phpmyadmin.yourdomain.com`

### Setup

phpMyAdmin is automatically configured when you start the infrastructure:

```bash
docker-compose up -d
```

### Login Credentials

**Local Development (`docker-compose.yml`):**
- May auto-login or prompt for credentials
- Uses environment variables `PMA_USER` and `PMA_PASSWORD` if set

**Production (`docker-compose.prod.yml`):**
- **ALWAYS requires manual MySQL login** - no auto-login
- You must enter MySQL username and password on the login page
- Available users:
  - **Root:** Username `root`, Password from `MYSQL_ROOT_PASSWORD` in `.env`
  - **Client users:** Username `{client}_user` (e.g., `client1_user`), Password from database setup
  - **Any MySQL user:** Any user created in MySQL can login with their credentials

### Features

- Manage all MySQL databases
- Create/modify/delete databases and tables
- Run SQL queries
- Import/export databases
- User management (when logged in as root)

### Security

- **Local Development:** 
  - Accessible via HTTP
  - May have auto-login for convenience
- **Production:** 
  - Uses HTTPS (SSL certificate via Let's Encrypt)
  - **Requires MySQL username/password login** - no auto-login enabled
  - Each user must authenticate with their MySQL credentials
  - Configuration: `traefik/phpmyadmin/config.user.inc.php`
- **Recommendation:** 
  - Use strong MySQL passwords
  - Restrict access to trusted IPs or use VPN in production

## phpLiteAdmin - SQLite Administration

### Access

- **Local Development:** `http://phpliteadmin.example.com`
- **Production:** `https://phpliteadmin.yourdomain.com`

### Initial Setup

phpLiteAdmin needs to be downloaded and configured once:

```bash
cd phpliteadmin
./setup.sh
```

This will:
1. Download phpLiteAdmin
2. Enable subdirectory browsing
3. Warn you to set a password

### Set Password

**IMPORTANT:** Change the default password before using in production!

Edit `phpliteadmin/phpliteadmin.php`:
```php
// Find this line:
$password = '';

// Change to:
$password = 'your-secure-password';
```

### Accessing Client Databases

1. Navigate to phpLiteAdmin
2. In the directory browser, navigate to: `/clients/`
3. Select a client folder (e.g., `client1/`)
4. Navigate to `database/` subfolder
5. Click on the `.db` or `.sqlite` file to open it

**Example paths:**
- `/clients/client1/database/app.db`
- `/clients/client2/database/app.db`

### Features

- Browse and manage SQLite databases
- View tables and data
- Execute SQL queries
- Import/export data
- Create/manage SQLite files

### Security

1. **Set a strong password** (see above)
2. **Restrict access** in production
3. **Read-only access:** Client databases are mounted read-only, so modifications must be made from within client containers

## Adding Host Entries (Local Development)

To access admin tools locally, add entries to `/etc/hosts`:

```bash
cd clients
./add-hosts.sh 127.0.0.1
```

This automatically adds:
- All client domains
- `phpmyadmin.example.com`
- `phpliteadmin.example.com`

Or manually:
```
127.0.0.1 phpmyadmin.example.com
127.0.0.1 phpliteadmin.example.com
```

## Production Configuration

### Update Domains

Edit `docker-compose.yml` or `docker-compose.prod.yml` and update the Traefik labels:

**phpMyAdmin:**
```yaml
- "traefik.http.routers.phpmyadmin.rule=Host(`phpmyadmin.yourdomain.com`)"
```

**phpLiteAdmin:**
```yaml
- "traefik.http.routers.phpliteadmin.rule=Host(`phpliteadmin.yourdomain.com`)"
```

### DNS Configuration

Point your domains to your server IP:
- `phpmyadmin.yourdomain.com` → Server IP
- `phpliteadmin.yourdomain.com` → Server IP

SSL certificates will be automatically provisioned by Let's Encrypt.

## Troubleshooting

### phpMyAdmin cannot connect to MySQL

1. Check if MySQL container is running: `docker ps | grep mysql`
2. Verify network: `docker network inspect web`
3. Check MySQL logs: `docker logs mysql`

### phpLiteAdmin cannot see client databases

1. Ensure databases are in `clients/{client}/database/` directory
2. Check file permissions
3. Verify `subdirectories = true` in `phpliteadmin.php`

### Access Denied

- **phpMyAdmin:** Verify MySQL credentials
- **phpLiteAdmin:** Check password in `phpliteadmin.php`

## Best Practices

1. **Strong Passwords:** Use complex passwords for both tools
2. **HTTPS Only:** In production, disable HTTP (Traefik redirects automatically)
3. **IP Restrictions:** Consider firewall rules to restrict access
4. **Regular Updates:** Keep containers updated
5. **Backup First:** Always backup databases before making changes

