# Production Deployment Guide

This guide explains how to deploy the infrastructure to production.

## Prerequisites

1. **Server Requirements:**
   - Ubuntu 20.04+ or similar Linux distribution
   - Docker and Docker Compose installed
   - Domain names pointing to your server's IP address (A records)
   - Ports 80 and 443 open in firewall

2. **Domain Setup:**
   - Ensure all client domains have DNS A records pointing to your server IP
   - Example: `client1.yourdomain.com` → `123.45.67.89`

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo>
cd sahajanand-server-infrastructure

# Copy environment file
cp .env.example .env

# Edit .env with your values
nano .env
```

### 2. Configure Environment Variables

Edit `.env` file:
```bash
EMAIL=your-real-email@yourdomain.com
TRAEFIK_LOG_LEVEL=INFO
```

### 3. Prepare SSL Directory

```bash
mkdir -p ssl
touch ssl/acme.json
chmod 600 ssl/acme.json
```

### 4. Configure phpMyAdmin for Production Login

phpMyAdmin is configured to require MySQL username and password login in production.

**Optional: Update blowfish secret for cookie encryption:**

```bash
# Generate a secure secret
openssl rand -base64 32

# Edit the config file
nano traefik/phpmyadmin/config.user.inc.php

# Replace CHANGE_THIS_SECRET_IN_PRODUCTION_USE_STRONG_RANDOM_STRING
# with your generated secret
```

**Note:** The default secret works, but change it for better security.

### 5. Start Infrastructure

```bash
# Start Traefik with production configuration
docker-compose -f docker-compose.prod.yml --env-file .env up -d

# Verify Traefik is running
docker-compose -f docker-compose.prod.yml ps
docker logs traefik
```

### 6. Deploy Clients

For each client:

```bash
cd clients/client1

# Update docker-compose.yml with your real domain:
# Change: Host(`client1.example.com`)
# To:     Host(`client1.yourdomain.com`)

# Start the client
docker-compose up -d --build

# Verify it's running
docker logs client1
```

### 7. Access phpMyAdmin

In production, phpMyAdmin requires MySQL username and password:

1. Navigate to `https://phpmyadmin.yourdomain.com`
2. You'll see the phpMyAdmin login page
3. Enter MySQL credentials:
   - **Server:** mysql (or leave default)
   - **Username:** MySQL username (e.g., `root`, `client1_user`, `client2_user`)
   - **Password:** MySQL password for that user
4. Click "Go" to login

**Available logins:**
- **Root:** Username `root`, Password from `MYSQL_ROOT_PASSWORD` in `.env`
- **Client users:** Username `{client}_user` (e.g., `client1_user`), Password from database setup
- **Any MySQL user:** Can login with their MySQL credentials

### 8. Verify SSL Certificates

```bash
# Check Traefik logs for SSL certificate status
docker logs traefik | grep -i acme

# Test your domain
curl -I https://client1.yourdomain.com
```

## Configuration Details

### Traefik Dashboard Security

The production configuration binds the dashboard to `127.0.0.1:8080` (localhost only).

To access it remotely, use SSH tunnel:
```bash
ssh -L 8080:localhost:8080 user@your-server-ip
# Then visit http://localhost:8080 in your browser
```

### SSL Certificates

- Certificates are automatically obtained from Let's Encrypt
- Stored in `./ssl/acme.json`
- Automatically renewed before expiration
- First certificate may take a few minutes

### Client Configuration

Each client's `docker-compose.yml` needs:
1. **Real domain** in Traefik labels
2. **Correct network name** matching the project

Example production labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.client1.rule=Host(`client1.yourdomain.com`)"
  - "traefik.http.routers.client1.entrypoints=websecure"
  - "traefik.http.routers.client1.tls.certresolver=letsencrypt"
```

## Firewall Configuration

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Optional: Allow SSH (if not already enabled)
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable
```

## Monitoring

### Check Service Status

```bash
# All services
docker-compose -f docker-compose.prod.yml ps

# Specific client
docker logs client1 --tail 50 -f
```

### Check Logs

```bash
# Traefik logs
tail -f logs/traefik/traefik.log

# Access logs
tail -f logs/traefik/access.log
```

### SSL Certificate Status

```bash
# Check certificate expiration
docker exec traefik cat /ssl/acme.json | grep -i expiry

# Or use Traefik dashboard API
curl http://localhost:8080/api/rawdata | jq '.certificates'
```

## Troubleshooting

### SSL Certificate Issues

1. **Check DNS:** Ensure domain points to server IP
   ```bash
   dig client1.yourdomain.com
   ```

2. **Check logs:** Look for ACME errors
   ```bash
   docker logs traefik | grep -i acme
   ```

3. **Test Let's Encrypt connectivity:**
   ```bash
   curl https://acme-v02.api.letsencrypt.org/directory
   ```

### Container Network Issues

If clients can't connect:
```bash
# Verify network exists
docker network ls | grep web

# Check if containers are on same network
docker network inspect web
```

### Port Conflicts

If ports 80/443 are in use:
```bash
# Check what's using the ports
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting services
sudo systemctl stop apache2  # or nginx
```

## Security Best Practices

1. **Keep Docker updated:**
   ```bash
   sudo apt update && sudo apt upgrade docker.io docker-compose
   ```

2. **Regular backups:**
   - Backup `ssl/acme.json` (contains SSL certificates)
   - Backup client application files

3. **Monitor logs regularly:**
   ```bash
   # Set up log rotation
   sudo nano /etc/logrotate.d/traefik
   ```

4. **Update Traefik:**
   ```bash
   # Check for updates
   docker pull traefik:v3.0
   docker-compose -f docker-compose.prod.yml up -d traefik
   ```

5. **Restrict dashboard access:** Already configured to localhost only

## Backup and Restore

### Backup SSL Certificates

```bash
# Backup acme.json
cp ssl/acme.json ssl/acme.json.backup-$(date +%Y%m%d)
```

### Backup Client Data

```bash
# Each client's files are in clients/client1/
tar -czf client1-backup-$(date +%Y%m%d).tar.gz clients/client1/
```

## Scaling

To add more clients:
1. Create new client folder: `clients/client2/`
2. Copy `client1/docker-compose.yml` and update domain
3. Deploy: `cd clients/client2 && docker-compose up -d --build`

## Updates

### Update a Client

```bash
cd clients/client1
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Update Traefik

```bash
docker-compose -f docker-compose.prod.yml pull traefik
docker-compose -f docker-compose.prod.yml up -d traefik
```

## Support

For issues:
1. Check logs: `docker logs traefik` and `docker logs <client-name>`
2. Verify DNS: `dig <domain>`
3. Check firewall: `sudo ufw status`
4. Verify SSL directory permissions: `ls -la ssl/`

