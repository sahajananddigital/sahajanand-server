# WordPress Multi-Client Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)

A Docker-based infrastructure for managing multiple WordPress clients with **shared PHP, database, and Redis services**, optimized for Hetzner ARM servers. Efficiently host 50+ WordPress sites on a single 4GB server with zero per-client container overhead.

## 🌟 Features

- ✅ **Shared PHP Service** - One PHP-FPM container serves all clients
- ✅ **Shared Database** - One MariaDB with separate databases per client  
- ✅ **Shared Redis Cache** - One Redis with prefix isolation
- ✅ **Zero Per-Client Containers** - No individual containers needed
- ✅ **Automatic SSL** - Traefik with Let's Encrypt
- ✅ **Resource Efficient** - 50+ clients on 4GB RAM server
- ✅ **Easy Management** - Simple CLI tools
- ✅ **Git-Friendly** - Track each client separately

## 🏗️ Architecture

- **Shared PHP Service** - One PHP-FPM container serves all clients
- **Shared Database Service** - One MariaDB container serves all clients (separate databases per client)
- **Shared Redis Service** - One Redis container serves all clients (prefix-based isolation)
- **Shared Nginx Router** - Routes domains to client directories
- **Zero Per-Client Containers** - Clients are just directories + configs
- **Individual Client Data** - Each client has their own uploads, themes, plugins
- **Centralized Management** - Mu-plugins provide admin interfaces
- **Git-Friendly** - Track each client separately
- **Resource Optimized** - 50+ clients on 4GB ARM server (only 2GB RAM usage)

## 📋 Prerequisites

- Hetzner ARM server (4GB+ RAM recommended)
- Docker and Docker Compose installed
- Domain names for your clients
- Basic command line knowledge

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd sahajanand-server-infrastructure

# Make scripts executable
chmod +x scripts/*.sh

# Test the setup
./scripts/test-setup.sh
```

### 2. Configure Environment

```bash
# Copy environment template
cp env.example .env

# Edit configuration
nano .env
```

**Required Configuration:**
```bash
BASE_DOMAIN=yourdomain.com
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_PASSWORD=your_secure_wordpress_password
EMAIL=your-email@example.com
SERVER_IP=your_server_ip
```

### 3. Deploy Base Infrastructure

```bash
# Deploy base services (Traefik, Portainer, etc.)
./scripts/deploy-infrastructure.sh
```

### 4. Create Your First Client

```bash
# Create a new client
./scripts/client-manager.sh create acme-corp acme.com

# Deploy the client
./scripts/client-manager.sh deploy acme-corp
```

## 📖 Detailed Usage

### Client Management

#### Create a New Client

```bash
# Create client with custom name and domain
./scripts/client-manager.sh create client-name domain.com

# Example
./scripts/client-manager.sh create my-company mycompany.com
```

#### Deploy/Manage Clients

```bash
# Deploy a client
./scripts/client-manager.sh deploy client-name

# Start a client
./scripts/client-manager.sh start client-name

# Stop a client
./scripts/client-manager.sh stop client-name

# Restart a client
./scripts/client-manager.sh restart client-name

# Remove a client (with confirmation)
./scripts/client-manager.sh remove client-name
```

#### Monitor Clients

```bash
# List all clients
./scripts/client-manager.sh list

# Check client status
./scripts/client-manager.sh status client-name

# View client logs
./scripts/client-manager.sh logs client-name
```

### WordPress Management

#### Access Client Admin

1. **Via Domain**: `https://client-domain.com/wp-admin`
2. **Via Portainer**: `https://admin.yourdomain.com`
3. **Via Traefik Dashboard**: `http://your-server-ip:8080`

#### Client Manager (Mu-Plugin)

Each client has a "Client Manager" menu in WordPress admin:

- **Client Information** - Shows client details and system info
- **Health Check** - Tests system components
- **Cache Management** - Flush caches
- **Backup Creation** - Create database backups

#### Update Manager (Mu-Plugin)

Centralized update management:

- **WordPress Core Updates** - Update WordPress for all clients
- **Plugin Updates** - Update plugins across all clients
- **Theme Updates** - Update themes across all clients
- **Update Notifications** - Shows available updates

### Shared WordPress Updates

```bash
# Update shared WordPress files (affects all clients)
./scripts/update-shared-wordpress.sh
```

This updates:
- WordPress core
- Shared themes
- Shared plugins
- Mu-plugins

### Infrastructure Management

#### Base Infrastructure

```bash
# Deploy base infrastructure
./scripts/deploy-infrastructure.sh

# Check infrastructure status
docker-compose -f docker-compose.base.yml ps

# View infrastructure logs
docker-compose -f docker-compose.base.yml logs -f
```

#### Resource Monitoring

```bash
# Check resource usage
docker stats

# Check specific client resources
docker stats wordpress-client-name
```

## 📁 File Structure

```
sahajanand-server-infrastructure/
├── docker-compose.base.yml              # Base infrastructure (shared services)
├── docker-compose.override.yml          # Optional local overrides
├── env.example                          # Environment template
├── wordpress/                           # Shared WordPress files
│   ├── wp-config-shared.php            # Shared configuration
│   ├── mu-plugins/                     # Must-use plugins
│   │   ├── object-cache.php            # Redis object cache
│   │   ├── client-manager.php          # Client management
│   │   └── update-manager.php          # Update management
│   ├── themes/                         # Shared themes
│   └── uploads/                        # Shared uploads
├── clients/                            # Client-specific files
│   └── {client-name}/                  # Each client directory
│       ├── .env                        # Client environment
│       ├── wp-config.php               # Client-specific config
│       └── wp-content/                 # Client WordPress content
│           ├── themes/                 # Client-specific themes
│           ├── plugins/                # Client-specific plugins
│           ├── uploads/                # Client uploads
│           └── backups/                # Client backups
├── nginx/                               # Nginx configuration
│   ├── nginx.conf                      # Main Nginx config
│   ├── client-template.conf            # Client config template
│   └── conf.d/                         # Generated client configs
├── php-fpm/                             # PHP-FPM configuration
│   ├── Dockerfile                       # PHP-FPM Docker image
│   └── entrypoint.sh                   # PHP-FPM entrypoint
├── scripts/                             # Management scripts
│   ├── client-manager.sh               # Client management
│   ├── deploy-infrastructure.sh        # Deploy base infrastructure
│   ├── create-client-db.sh             # Create client databases
│   ├── init-wordpress.sh               # Initialize WordPress
│   ├── update-nginx-config.sh          # Update Nginx configs
│   ├── update-shared-wordpress.sh      # Update shared WordPress
│   └── test-setup.sh                   # Test setup
└── traefik/                             # Traefik configuration
    ├── traefik.yml                     # Main config
    └── dynamic.yml                     # Dynamic config
```

## 🔧 Configuration Options

### Resource Limits

**Base Infrastructure (Shared):**
- Traefik: 128MB RAM
- Portainer: 128MB RAM
- Watchtower: 64MB RAM
- MariaDB Shared: 768MB RAM
- Redis Shared: 320MB RAM
- PHP-FPM Shared: 512MB RAM
- Nginx Router: 128MB RAM
- **Total Base**: ~2GB RAM

**Per Client:**
- **No individual containers needed!**
- Just directory structure and Nginx config
- **0MB RAM per client** (no containers)

### Server Capacity (With Shared Services)

| Server RAM | Max Clients | Resource Usage |
|------------|-------------|----------------|
| 4GB        | 50+ clients | ~2GB RAM       |
| 8GB        | 100+ clients| ~2GB RAM       |
| 16GB       | 200+ clients| ~2GB RAM       |

**Note**: With shared PHP, database, and Redis services, clients require **0MB RAM per client** (no individual containers). Base infrastructure uses ~2GB RAM regardless of client count.

## 🛠️ Troubleshooting

### Common Issues

#### Client Won't Start

```bash
# Check client status
./scripts/client-manager.sh status client-name

# View logs
./scripts/client-manager.sh logs client-name

# Check Docker logs
docker logs wordpress-client-name
```

#### Database Connection Issues

```bash
# Check database container
docker logs mariadb-client-name

# Test database connection
docker exec -it mariadb-client-name mysql -u wordpress -p
```

#### Memory Issues

```bash
# Check memory usage
docker stats

# Restart containers to free memory
docker-compose -f docker-compose.base.yml restart
```

#### SSL Certificate Issues

```bash
# Check Traefik logs
docker logs traefik

# Verify domain DNS
nslookup your-domain.com
```

### Log Locations

- **Traefik**: `logs/traefik/`
- **Client Logs**: `docker logs wordpress-client-name`
- **Database Logs**: `docker logs mariadb-client-name`

### Backup and Restore

#### Create Backup

```bash
# Backup specific client
./scripts/client-manager.sh backup client-name

# Manual database backup
docker exec mariadb-client-name mysqldump -u wordpress -p wordpress_client_name > backup.sql
```

#### Restore Backup

```bash
# Restore database
docker exec -i mariadb-client-name mysql -u wordpress -p wordpress_client_name < backup.sql
```

## 🔒 Security

### SSL Certificates

- **Automatic**: Let's Encrypt certificates via Traefik
- **Manual**: Place certificates in `ssl/` directory

### Database Security

- **Unique passwords** per client
- **Isolated databases** per client
- **No external access** to databases

### File Permissions

```bash
# Set proper permissions
chmod 755 wordpress/
chmod 644 wordpress/wp-config-shared.php
chmod 755 clients/
```

## 📈 Scaling

### Adding More Clients

1. **Check resources**: `docker stats`
2. **Create client**: `./scripts/client-manager.sh create new-client domain.com`
3. **Deploy client**: `./scripts/client-manager.sh deploy new-client`

### Upgrading Server

1. **Backup all clients**
2. **Export configurations**
3. **Deploy on new server**
4. **Import client data**

### Load Balancing

For high traffic, consider:
- **Multiple servers** with load balancer
- **CDN** for static assets
- **Database clustering** for large datasets

## 🆘 Support

### Getting Help

1. **Check logs**: `./scripts/client-manager.sh logs client-name`
2. **Test setup**: `./scripts/test-setup.sh`
3. **Check resources**: `docker stats`
4. **Verify configuration**: `docker-compose config`

### Useful Commands

```bash
# View all containers
docker ps -a

# Check disk usage
df -h

# Check memory usage
free -h

# Restart all services
docker-compose -f docker-compose.base.yml restart
```

## 📝 Best Practices

### Client Management

1. **Use descriptive names** for clients
2. **Regular backups** of important clients
3. **Monitor resource usage** regularly
4. **Keep WordPress updated** via shared updates

### Security

1. **Strong passwords** for all accounts
2. **Regular updates** of all components
3. **Monitor access logs**
4. **Backup before major changes**

### Performance

1. **Use optimized template** for many clients
2. **Monitor memory usage**
3. **Optimize images** before upload
4. **Use caching** effectively

## 🎯 Next Steps

1. **Deploy your first client**
2. **Test all functionality**
3. **Set up monitoring**
4. **Create backup strategy**
5. **Scale as needed**

---

**Happy hosting! 🚀**