# Shared Services Architecture

## 🎯 **Overview**

This infrastructure uses **shared database and Redis services** for all clients, dramatically reducing resource usage and simplifying management.

## 🏗️ **Architecture**

### **Shared Services (Base Infrastructure)**
- ✅ **One MariaDB Container** - All clients use this (separate databases)
- ✅ **One Redis Container** - All clients use this (with prefixes for isolation)
- ✅ **Traefik** - Reverse proxy for all clients
- ✅ **Portainer** - Container management
- ✅ **Watchtower** - Auto-updates

### **Per Client (Individual Containers)**
- ✅ **WordPress Container** - One per client (isolated PHP/Apache)

### **Isolation Strategy**
- **Database**: Separate databases per client (`wordpress_client1`, `wordpress_client2`, etc.)
- **Redis**: Client-specific prefixes (`wp_client1:`, `wp_client2:`, etc.)
- **Files**: Separate volumes per client
- **Networks**: Shared internal network for communication

## 📊 **Resource Usage**

### **Base Infrastructure (Shared)**
- Traefik: 128MB RAM
- Portainer: 128MB RAM
- Watchtower: 64MB RAM
- **MariaDB Shared**: 768MB RAM ⬅️ *One for all clients*
- **Redis Shared**: 320MB RAM ⬅️ *One for all clients*
- **Total Base**: 1.4GB RAM

### **Per Client**
- WordPress: 256MB RAM
- **Total per Client**: 256MB RAM ⬅️ *Much less than before!*

### **Capacity Examples**

| Server RAM | Max Clients | Total Usage |
|------------|-------------|-------------|
| 4GB        | 10 clients  | ~3.9GB      |
| 8GB        | 25 clients  | ~7.7GB      |
| 16GB       | 55+ clients | ~15GB       |

## ✅ **Benefits**

### **1. Resource Efficiency**
- **Before**: ~736MB per client (WordPress + DB + Redis)
- **After**: ~256MB per client (WordPress only)
- **Savings**: ~65% reduction per client!

### **2. Better Resource Management**
- **One database pool** - Better connection management
- **Shared Redis** - More efficient caching
- **Easier scaling** - Just add more WordPress containers

### **3. Simplified Management**
- **One database** to backup and maintain
- **One Redis** to monitor
- **Centralized logs** for shared services

### **4. Cost Savings**
- **More clients** on same server
- **Lower infrastructure** costs
- **Better resource utilization**

## 🔒 **Security & Isolation**

### **Database Isolation**
Each client has:
- ✅ **Separate database** (`wordpress_clientname`)
- ✅ **Isolated data** - No cross-client access
- ✅ **Unique credentials** - Same user, different databases

### **Redis Isolation**
- ✅ **Prefix-based isolation** (`wp_clientname:`)
- ✅ **No key collisions** - Automatic separation
- ✅ **Safe caching** - Per-client cache namespaces

### **File Isolation**
- ✅ **Separate volumes** per client
- ✅ **Separate containers** per client
- ✅ **No file sharing** between clients

## 🚀 **Usage**

### **Deploy Base Infrastructure**
```bash
# Deploy shared services (one time)
./scripts/deploy-infrastructure.sh
```

This creates:
- `mariadb-shared` - Shared database service
- `redis-shared` - Shared cache service
- Other base services

### **Create Clients**
```bash
# Create client (automatically creates database)
./scripts/client-manager.sh create client-name domain.com

# Deploy client
./scripts/client-manager.sh deploy client-name
```

The client manager automatically:
- ✅ Creates database on shared MariaDB
- ✅ Configures Redis prefix
- ✅ Sets up WordPress container

## 🛠️ **Database Management**

### **List All Databases**
```bash
docker exec -it mariadb-shared mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"
```

### **Create Database Manually**
```bash
./scripts/create-client-db.sh client-name
```

### **Backup Database**
```bash
docker exec mariadb-shared mysqldump -uroot -p${MYSQL_ROOT_PASSWORD} wordpress_clientname > backup.sql
```

### **Restore Database**
```bash
docker exec -i mariadb-shared mysql -uroot -p${MYSQL_ROOT_PASSWORD} wordpress_clientname < backup.sql
```

## 📈 **Monitoring**

### **Check Shared Services**
```bash
# Check MariaDB
docker logs mariadb-shared

# Check Redis
docker logs redis-shared

# Resource usage
docker stats mariadb-shared redis-shared
```

### **Check Client WordPress**
```bash
# Check specific client
docker logs wordpress-client-name

# Resource usage
docker stats wordpress-client-name
```

## ⚠️ **Important Notes**

### **1. Database Connections**
- **Shared pool**: All clients share database connections
- **Limit**: 100 max connections total (configurable)
- **Monitoring**: Watch connection usage with many clients

### **2. Redis Memory**
- **Shared cache**: 256MB total for all clients
- **LRU eviction**: Old keys automatically removed
- **Monitoring**: Watch memory usage with many clients

### **3. Backup Strategy**
- **Database backups**: Backup entire MariaDB or per-database
- **Volume backups**: Backup each client's WordPress volume
- **Redis**: Usually doesn't need backup (cache only)

### **4. Scaling**
- **Horizontal**: Add more servers with shared services
- **Vertical**: Increase MariaDB/Redis resources
- **Monitoring**: Track resource usage before limits

## 🔄 **Migration from Old Setup**

If you have existing clients with individual databases:

1. **Stop old client containers**
2. **Export databases**
3. **Import to shared MariaDB**
4. **Update client compose files**
5. **Redeploy clients**

The client manager handles this automatically!

## 📊 **Comparison**

| Aspect | Old (Individual) | New (Shared) |
|--------|------------------|--------------|
| **DB Containers** | 1 per client | 1 total |
| **Redis Containers** | 1 per client | 1 total |
| **RAM per Client** | ~736MB | ~256MB |
| **10 Clients RAM** | ~7.7GB | ~3.9GB |
| **Management** | Complex | Simple |
| **Backup** | Per-client | Centralized |

## 🎯 **Best Practices**

1. **Monitor shared services** - Watch MariaDB and Redis usage
2. **Regular backups** - Backup shared database regularly
3. **Connection pooling** - Monitor database connections
4. **Cache management** - Monitor Redis memory
5. **Resource limits** - Set appropriate limits on shared services

---

**This architecture gives you maximum efficiency with proper isolation!** 🚀
