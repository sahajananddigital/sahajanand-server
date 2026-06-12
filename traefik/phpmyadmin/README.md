# phpMyAdmin Production Configuration

This directory contains configuration to force MySQL username/password authentication in phpMyAdmin for production.

## What This Does

In production, phpMyAdmin will **require** users to enter MySQL credentials (username and password) before accessing any databases. There is no auto-login.

## Configuration File

The `config.user.inc.php` file is mounted into the phpMyAdmin container and:
- Forces cookie-based authentication (manual login)
- Disables auto-login
- Requires username and password for all connections

## Setup

1. **Generate a strong blowfish secret** (for cookie encryption):

   ```bash
   openssl rand -base64 32
   ```

2. **Update the config file:**

   Edit `traefik/phpmyadmin/config.user.inc.php` and replace:
   ```php
   $cfg['blowfish_secret'] = 'CHANGE_THIS_SECRET_IN_PRODUCTION_USE_STRONG_RANDOM_STRING';
   ```
   
   With your generated secret:
   ```php
   $cfg['blowfish_secret'] = 'your-generated-secret-here';
   ```

3. **Restart phpMyAdmin:**

   ```bash
   docker-compose restart phpmyadmin
   ```

## How It Works

All configurations are driven by your `.env` file (managed automatically by `setup.sh`):

### Local Development Mode
- Configured via `setup.sh` (option 2)
- Automatically sets `PMA_USER=root` and `PMA_PASSWORD` to log in without prompting

### Production Mode
- Configured via `setup.sh` (option 1)
- Leaves `PMA_USER` and `PMA_PASSWORD` unset, forcing users to enter their MySQL username and password manually on the login screen
- Enforces cookie authentication for improved security

## Login Process

When accessing phpMyAdmin in production:

1. Navigate to `https://phpmyadmin.yourdomain.com`
2. phpMyAdmin login page appears
3. Enter:
   - **Server:** mysql (or leave default)
   - **Username:** MySQL username (e.g., `root`, `client1_user`)
   - **Password:** MySQL password for that user
4. Click "Go" to login

## Security Benefits

- ✅ No hardcoded credentials in environment variables
- ✅ Each user uses their own MySQL credentials
- ✅ Supports multiple users (root, client1_user, client2_user, etc.)
- ✅ Cookie-based session management
- ✅ Secure over HTTPS (enforced by Traefik)

## Troubleshooting

### Can't login

1. Verify MySQL credentials are correct
2. Check if user exists: `docker exec -it mysql mysql -u root -p -e "SELECT User FROM mysql.user;"`
3. Test connection directly: `docker exec -it mysql mysql -u <username> -p`

### Configuration not applying

1. Check if config file is mounted: `docker exec phpmyadmin ls -la /etc/phpmyadmin/config.user.inc.php`
2. Verify syntax: `docker exec phpmyadmin php -l /etc/phpmyadmin/config.user.inc.php`
3. Check phpMyAdmin logs: `docker logs phpmyadmin`

### Want to use different users

Any MySQL user can login:
- Root user: Username `root`, Password from `MYSQL_ROOT_PASSWORD` in `.env`
- Client users: Username `client1_user`, Password from database setup
- Custom users: Any MySQL user you've created

