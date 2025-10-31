# Quick Start Guide

## 🚀 5-Minute Setup

### 1. Initial Setup
```bash
# Clone and setup
git clone <your-repo>
cd sahajanand-server-infrastructure
chmod +x scripts/*.sh

# Test everything
./scripts/test-setup.sh
```

### 2. Configure
```bash
# Copy and edit environment
cp env.example .env
nano .env
```

**Required in .env:**
```bash
BASE_DOMAIN=yourdomain.com
MYSQL_ROOT_PASSWORD=secure_password_123
MYSQL_PASSWORD=wordpress_password_123
EMAIL=your-email@example.com
SERVER_IP=your_server_ip
```

### 3. Deploy Infrastructure
```bash
# Deploy base services
./scripts/deploy-infrastructure.sh
```

### 4. Create First Client
```bash
# Create client
./scripts/client-manager.sh create my-client myclient.com

# Deploy client
./scripts/client-manager.sh deploy my-client
```

### 5. Access Your Site
- **Website**: `https://myclient.com`
- **Admin**: `https://myclient.com/wp-admin`
- **Portainer**: `https://admin.yourdomain.com`
- **Traefik Dashboard**: `http://your-server-ip:8080`

## 📋 Essential Commands

### Client Management
```bash
# List all clients
./scripts/client-manager.sh list

# Create new client with single domain
./scripts/client-manager.sh create client-name domain.com

# Create client with multiple domains
./scripts/client-manager.sh create client-name domain.com www.domain.com shop.domain.com

# Deploy client
./scripts/client-manager.sh deploy client-name

# Domain management
./scripts/client-manager.sh add-domain client-name new-domain.com
./scripts/client-manager.sh remove-domain client-name old-domain.com
./scripts/client-manager.sh list-domains client-name

# Start/stop client
./scripts/client-manager.sh start client-name
./scripts/client-manager.sh stop client-name

# Check status
./scripts/client-manager.sh status client-name

# View logs
./scripts/client-manager.sh logs client-name
```

### WordPress Updates
```bash
# Update shared WordPress (affects all clients)
./scripts/update-shared-wordpress.sh
```

### Infrastructure
```bash
# Check all services
docker ps

# Check resource usage
docker stats

# Restart base infrastructure
docker-compose -f docker-compose.base.yml restart
```

## 🔧 Architecture

### Shared Services
- **One PHP-FPM service** serves all clients
- **One MariaDB service** with separate databases per client
- **One Redis service** with prefix isolation per client
- **One Nginx router** routes domains to client directories
- **No individual containers** per client needed

## 🆘 Troubleshooting

### Client Won't Start
```bash
# Check logs
./scripts/client-manager.sh logs client-name

# Check Docker logs
docker logs wordpress-client-name
```

### Memory Issues
```bash
# Check memory usage
docker stats

# Restart services
docker-compose -f docker-compose.base.yml restart
```

### Database Issues
```bash
# Check database logs
docker logs mariadb-client-name

# Test connection
docker exec -it mariadb-client-name mysql -u wordpress -p
```

## 📊 Resource Usage

| Server RAM | Max Clients | Total RAM Usage | Best For |
|------------|-------------|-----------------|----------|
| 4GB | 50+ | ~2GB | Development/Testing |
| 8GB | 100+ | ~2GB | Production |
| 16GB | 200+ | ~2GB | Large Scale |

## 🎯 Next Steps

1. **Test your first client**
2. **Create more clients as needed**
3. **Set up monitoring**
4. **Create backup strategy**
5. **Scale when ready**

---

**Need help? Check the full README.md for detailed instructions!**
