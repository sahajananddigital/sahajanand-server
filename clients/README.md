# PHP Clients Directory

This directory contains individual PHP client applications, each with their own Dockerfile and container configuration.

## Structure

Each client should be placed in its own folder:
```
clients/
  ├── client1/
  │   ├── Dockerfile
  │   ├── docker-compose.yml
  │   ├── nginx.conf
  │   ├── .dockerignore
  │   └── [your PHP application files]
  ├── client2/
  │   ├── Dockerfile
  │   ├── docker-compose.yml
  │   ├── nginx.conf
  │   ├── .dockerignore
  │   └── [your PHP application files]
  └── ...
```

## Adding a New Client

1. Create a new folder for your client:
   ```bash
   mkdir -p clients/your-client-name
   ```

2. Copy the `Dockerfile`, `docker-compose.yml`, and `nginx.conf` from `client1/` and customize as needed

3. Add your PHP application files to the client folder (typically in a `public/` subdirectory for Laravel/other frameworks)

4. Update the `docker-compose.yml` in your client folder:
   - Change `container_name` to match your client name
   - Update the service name
   - Update all Traefik labels with your client name and domain

5. Update the domain name in the Traefik labels in `docker-compose.yml` to match your client's domain

6. Ensure the main infrastructure is running (Traefik and web network):
   ```bash
   # From project root
   docker-compose up -d
   ```

7. Build and start your client container:
   ```bash
   # From your client folder (e.g., clients/your-client-name/)
   docker-compose up -d --build
   ```
   
   Or from project root using the client's compose file:
   ```bash
   docker-compose -f clients/your-client-name/docker-compose.yml up -d --build
   ```

## Notes

- Each client has its own `docker-compose.yml` file for isolated configuration
- Each client uses PHP 8.2-FPM with Nginx
- Port 80 is exposed for Nginx (which communicates with PHP-FPM internally)
- All clients connect to the shared `web` network (created by the main docker-compose.yml) for Traefik routing
- SSL certificates are automatically provisioned via Let's Encrypt
- Security headers and gzip compression are applied by default
- Supervisor manages both Nginx and PHP-FPM processes in the container
- The main `docker-compose.yml` only contains Traefik; all client services are in their respective folders

## Database Support

### SQLite

SQLite support is included in all client containers:

- **PHP Extensions:** `pdo_sqlite` and `sqlite3` are installed
- **Database Directory:** Each client has a `database/` directory with write permissions
- **Usage Example:**
  ```php
  $db = new PDO('sqlite:/var/www/html/database/app.db');
  ```
  Or relative path:
  ```php
  $db = new PDO('sqlite:database/app.db');
  ```

**Note:** SQLite database files should be stored in the `database/` directory within each client folder. This directory has proper write permissions (775) for the web server.

### MySQL (Isolated Databases)

A shared MySQL container is available, but **each client has its own isolated database**:

- **Host:** `mysql` (container name)
- **Port:** `3306`
- **Database:** `{client_name}_db` (e.g., `client1_db`)
- **Username:** `{client_name}_user` (e.g., `client1_user`)
- **Password:** Set per client (default: `{client_name}_password`)

**Connection from PHP (client1 example):**
```php
$pdo = new PDO('mysql:host=mysql;dbname=client1_db', 'client1_user', 'client1_password');
```

**Security:**
- Each client can only access their own database
- Clients cannot see or access other clients' databases
- Independent credentials per client

**Setting up a new client database:**

1. **Use the helper script:**
   ```bash
   cd mysql
   ./add-client-db.sh client2
   ```

2. **Or add to initialization script** `mysql/init/01-create-client-databases.sql`

**Configuration:**
- Each client should have a `.env` file with their database credentials
- Copy `clients/client1/.env.example` to your client folder as `.env`
- Update the database name, username, and password

**For more details:** See `/mysql/README.md`

### PostgreSQL

For PostgreSQL, you can:
1. Add a PostgreSQL container to the main `docker-compose.yml` (similar to MySQL)
2. Use external database servers
3. Add database containers to individual client's `docker-compose.yml`

## Network Setup

The main `docker-compose.yml` creates a `web` network with an explicit name. Client compose files reference this network as external with `name: web`.

The network is always named `web` regardless of the project directory name, which ensures Traefik can find it correctly.

If you need to change the network name:
1. Update `networks.web.name` in the main `docker-compose.yml`
2. Update `networks.web.name` in each client's `docker-compose.yml` file
3. Update `network: web` in `traefik/traefik.yml`

## Host Entries for Local Development

Traefik routes traffic based on HTTP Host headers. For **local development**, you need to add entries to your `/etc/hosts` file so your browser can resolve the client domain names.

### Option 1: Use the Helper Script (Recommended)

Automatically add host entries for all clients:

```bash
# From the clients directory
./add-hosts.sh [server-ip]

# Example: If accessing from localhost
./add-hosts.sh 127.0.0.1

# Example: If accessing from a remote server
./add-hosts.sh 192.168.1.100
```

To remove the host entries:
```bash
./remove-hosts.sh
```

### Option 2: Manual Setup

Manually add entries to `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Add entries like:
```
127.0.0.1 client1.example.com
127.0.0.1 client2.example.com
```

### Production Setup

For **production**, configure DNS records (A or CNAME) to point your domains to your server's IP address. Traefik will automatically handle SSL certificates via Let's Encrypt once DNS is properly configured.

