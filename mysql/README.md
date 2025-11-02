# MySQL Database Setup

This directory contains configuration for the shared MySQL database container.

## Container Details

- **Container Name:** `mysql`
- **Network:** `web` (shared with all clients)
- **Image:** `mysql:8.0`
- **Port:** `3306` (configurable via `MYSQL_PORT` in `.env`)

## Isolated Database Architecture

**Each client has its own isolated database and user credentials.** This ensures:
- Data isolation between clients
- Security - clients cannot access other clients' data
- Independent permissions per client
- Easy database management per client

### Database Naming Convention

- **Database:** `{client_name}_db` (e.g., `client1_db`, `client2_db`)
- **Username:** `{client_name}_user` (e.g., `client1_user`, `client2_user`)
- **Password:** Set individually per client (default: `{client_name}_password`)

## Connection Details

### From PHP Client Containers

Each client connects to MySQL using their **own database and credentials**:

**Host:** `mysql` (the container name, not `localhost`)

**Example for client1:**
```php
$host = 'mysql';
$database = 'client1_db';      // Client-specific database
$username = 'client1_user';   // Client-specific user
$password = 'client1_password'; // Client-specific password

$pdo = new PDO("mysql:host=$host;dbname=$database", $username, $password);
```

### From Host Machine

To connect from your host machine (e.g., using MySQL client tools):

```bash
mysql -h 127.0.0.1 -P 3306 -u app_user -p app_db
```

Or use root:
```bash
mysql -h 127.0.0.1 -P 3306 -u root -p
```

## Environment Variables

Configure in `.env` file:

```bash
MYSQL_ROOT_PASSWORD=your-secure-root-password
MYSQL_DATABASE=app_db
MYSQL_USER=app_user
MYSQL_PASSWORD=your-secure-password
MYSQL_PORT=3306
```

## Adding a New Client Database

### Method 1: Using the Helper Script (Recommended)

```bash
cd mysql
./add-client-db.sh <client-name> [password]

# Example:
./add-client-db.sh client2
./add-client-db.sh client3 mycustompassword
```

This script automatically:
- Creates the database (`{client_name}_db`)
- Creates a dedicated user (`{client_name}_user`)
- Grants permissions only to that client's database
- Shows you the connection details

### Method 2: Manual SQL

Add to `mysql/init/01-create-client-databases.sql`:

```sql
CREATE DATABASE IF NOT EXISTS `client2_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'client2_user'@'%' IDENTIFIED BY 'client2_password';
GRANT ALL PRIVILEGES ON `client2_db`.* TO 'client2_user'@'%';
FLUSH PRIVILEGES;
```

Then restart MySQL container:
```bash
docker-compose restart mysql
```

### Method 3: Direct MySQL Command

```bash
docker exec -i mysql mysql -u root -p << EOF
CREATE DATABASE IF NOT EXISTS \`client2_db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'client2_user'@'%' IDENTIFIED BY 'client2_password';
GRANT ALL PRIVILEGES ON \`client2_db\`.* TO 'client2_user'@'%';
FLUSH PRIVILEGES;
EOF
```

## Initialization Scripts

The file `mysql/init/01-create-client-databases.sql` is executed automatically when MySQL container starts for the first time. Add new clients to this file or use the helper script above.

## Database Persistence

MySQL data is stored in a Docker volume named `mysql_data`, so data persists across container restarts.

## Managing the Database

### Access MySQL CLI

```bash
# From host
docker exec -it mysql mysql -u root -p

# Or from container
docker exec -it mysql mysql -u app_user -p app_db
```

### Backup Database

```bash
# Backup specific database
docker exec mysql mysqldump -u root -p app_db > backup.sql

# Backup all databases
docker exec mysql mysqldump -u root -p --all-databases > all_databases.sql
```

### Restore Database

```bash
docker exec -i mysql mysql -u root -p app_db < backup.sql
```

## Security Notes

1. **Change default passwords** in production
2. **Use strong passwords** for `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD`
3. **Limit network access** - MySQL is only accessible within the Docker network by default
4. **Regular backups** - Use the backup commands above

## Application Configuration Examples

### Laravel Configuration (client1 example)

In `clients/client1/.env`:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=client1_db
DB_USERNAME=client1_user
DB_PASSWORD=client1_password
```

### WordPress Configuration (client1 example)

In `clients/client1/wp-config.php`:

```php
define('DB_NAME', 'client1_db');
define('DB_USER', 'client1_user');
define('DB_PASSWORD', 'client1_password');
define('DB_HOST', 'mysql');
```

### Plain PHP PDO (client1 example)

```php
$pdo = new PDO(
    'mysql:host=mysql;dbname=client1_db;charset=utf8mb4',
    'client1_user',
    'client1_password',
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]
);
```

## Troubleshooting

### Connection Refused

1. Check if MySQL container is running: `docker ps | grep mysql`
2. Verify network: `docker network inspect web`
3. Check MySQL logs: `docker logs mysql`

### Access Denied

1. Verify credentials in `.env` file
2. Check if user exists: `docker exec -it mysql mysql -u root -p -e "SELECT User FROM mysql.user;"`
3. Reset password if needed

### Port Already in Use

Change `MYSQL_PORT` in `.env` to a different port if 3306 is already in use.

