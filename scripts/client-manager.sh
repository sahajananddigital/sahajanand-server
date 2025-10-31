#!/bin/bash

# Client Management Script
# Manages individual client Docker Compose files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLIENTS_DIR="clients"

# Function to show usage
show_usage() {
    echo -e "${BLUE}Client Management Script${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  create <client-name> <domain> [alt1] [alt2] [alt3]  Create a new client with multiple domains"
    echo "  deploy <client-name>              Deploy a client"
    echo "  start <client-name>               Start a client"
    echo "  stop <client-name>                Stop a client"
    echo "  restart <client-name>             Restart a client"
    echo "  remove <client-name>              Remove a client"
    echo "  list                              List all clients"
    echo "  status <client-name>              Show client status"
    echo "  logs <client-name>                Show client logs"
    echo "  backup <client-name>              Backup client data"
    echo "  restore <client-name> <backup>    Restore client from backup"
    echo "  update <client-name>              Update client WordPress"
    echo "  add-domain <client-name> <domain> Add additional domain to client"
    echo "  remove-domain <client-name> <domain> Remove domain from client"
    echo "  list-domains <client-name>        List all domains for client"
    echo ""
    echo "Examples:"
    echo "  $0 create acme-corp acme.com www.acme.com"
    echo "  $0 create my-company mycompany.com www.mycompany.com mycompany.net"
    echo "  $0 add-domain acme-corp shop.acme.com"
    echo "  $0 list-domains acme-corp"
    echo "  $0 list"
}

# Function to check if .env file exists
check_env() {
    if [ ! -f ".env" ]; then
        echo -e "${RED}❌ No .env file found. Please create one based on env.example${NC}"
        exit 1
    fi
}

# Function to create a new client
create_client() {
    local client_name=$1
    local domain=$2
    local alt1=$3
    local alt2=$4
    local alt3=$5
    
    if [ -z "$client_name" ] || [ -z "$domain" ]; then
        echo -e "${RED}❌ Usage: create <client-name> <domain> [alt1] [alt2] [alt3]${NC}"
        exit 1
    fi
    
    # Validate client name (alphanumeric and hyphens only)
    if [[ ! "$client_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo -e "${RED}❌ Client name must contain only letters, numbers, and hyphens${NC}"
        exit 1
    fi
    
    # Check if client already exists
    if [ -d "$CLIENTS_DIR/$client_name" ]; then
        echo -e "${RED}❌ Client '$client_name' already exists${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🏗️  Creating client: $client_name${NC}"
    
    # Create client directory
    mkdir -p "$CLIENTS_DIR/$client_name"
    
    # Create client environment file
    cat > "$CLIENTS_DIR/$client_name/.env" << EOF
# Client: $client_name
CLIENT_NAME=$client_name
CLIENT_DOMAIN=$domain
CLIENT_DOMAIN_ALT1=${alt1:-}
CLIENT_DOMAIN_ALT2=${alt2:-}
CLIENT_DOMAIN_ALT3=${alt3:-}
MYSQL_ROOT_PASSWORD=\${MYSQL_ROOT_PASSWORD}
MYSQL_PASSWORD=\${MYSQL_PASSWORD}
EOF
    
    # Create WordPress config that extends shared config
    cat > "$CLIENTS_DIR/$client_name/wp-config.php" << EOF
<?php
/**
 * Client-specific WordPress Configuration
 * Extends the shared WordPress configuration
 */

// Client-specific database configuration (using shared MariaDB)
define('DB_NAME', 'wordpress_$client_name');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', getenv('MYSQL_PASSWORD'));
define('DB_HOST', 'mariadb-shared:3306');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

// Client-specific authentication keys and salts
define('AUTH_KEY',         '$(openssl rand -base64 32)');
define('SECURE_AUTH_KEY',  '$(openssl rand -base64 32)');
define('LOGGED_IN_KEY',    '$(openssl rand -base64 32)');
define('NONCE_KEY',        '$(openssl rand -base64 32)');
define('AUTH_SALT',        '$(openssl rand -base64 32)');
define('SECURE_AUTH_SALT', '$(openssl rand -base64 32)');
define('LOGGED_IN_SALT',   '$(openssl rand -base64 32)');
define('NONCE_SALT',       '$(openssl rand -base64 32)');

// Client-specific Redis configuration (using shared Redis)
define('WP_REDIS_HOST', 'redis-shared');
define('WP_REDIS_PORT', 6379);
define('WP_REDIS_DATABASE', 0);
define('WP_REDIS_PREFIX', 'wp_$client_name:');

// Client identification
define('CLIENT_NAME', '$client_name');
define('CLIENT_DOMAIN', '$domain');

// WordPress paths
define('WP_CONTENT_DIR', __DIR__ . '/wp-content');
define('WP_CONTENT_URL', 'http://' . \$_SERVER['HTTP_HOST'] . '/wp-content');

// Load shared WordPress configuration
if (file_exists(__DIR__ . '/wp-config-shared.php')) {
    require_once(__DIR__ . '/wp-config-shared.php');
} elseif (file_exists('/shared-wordpress/wp-config-shared.php')) {
    require_once('/shared-wordpress/wp-config-shared.php');
}
EOF
    
    # Create directories
    mkdir -p "$CLIENTS_DIR/$client_name/wp-content/themes"
    mkdir -p "$CLIENTS_DIR/$client_name/wp-content/plugins"
    mkdir -p "$CLIENTS_DIR/$client_name/wp-content/uploads"
    mkdir -p "$CLIENTS_DIR/$client_name/wp-content/backups"
    
    # Initialize WordPress files for client
    echo -e "${BLUE}📦 Initializing WordPress files...${NC}"
    if docker exec php-fpm-shared /bin/bash -c "/init-wordpress.sh $client_name" 2>/dev/null || ./scripts/init-wordpress.sh "$client_name"; then
        echo -e "${GREEN}✅ WordPress files initialized${NC}"
    else
        echo -e "${YELLOW}⚠️  WordPress initialization failed. Will be completed on deployment.${NC}"
    fi
    
    # Generate Nginx configuration
    echo -e "${BLUE}🌐 Generating Nginx configuration...${NC}"
    if ./scripts/update-nginx-config.sh "$client_name" "$domain" "$alt1" "$alt2" "$alt3"; then
        echo -e "${GREEN}✅ Nginx configuration generated${NC}"
    else
        echo -e "${YELLOW}⚠️  Nginx configuration generation failed${NC}"
    fi
    
    # Create database on shared MariaDB service
    echo -e "${BLUE}🗄️  Creating database on shared MariaDB...${NC}"
    if ./scripts/create-client-db.sh "$client_name"; then
        echo -e "${GREEN}✅ Database created successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Database creation failed. You can create it manually later.${NC}"
        echo -e "${YELLOW}   Or ensure base infrastructure is running: ./scripts/deploy-infrastructure.sh${NC}"
    fi
    
    echo -e "${GREEN}✅ Client '$client_name' created successfully!${NC}"
    echo -e "${BLUE}📁 Client files: $CLIENTS_DIR/$client_name/${NC}"
    echo -e "${BLUE}🌐 Domains configured:${NC}"
    echo -e "  • Primary: $domain"
    [ -n "$alt1" ] && echo -e "  • Alt 1: $alt1"
    [ -n "$alt2" ] && echo -e "  • Alt 2: $alt2"
    [ -n "$alt3" ] && echo -e "  • Alt 3: $alt3"
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "  1. Deploy with: $0 deploy $client_name"
    echo -e "  2. Add to Git: git add $CLIENTS_DIR/$client_name/ nginx/conf.d/${client_name}.conf"
}

# Function to add domain to client
add_domain() {
    local client_name=$1
    local new_domain=$2
    
    if [ -z "$client_name" ] || [ -z "$new_domain" ]; then
        echo -e "${RED}❌ Usage: add-domain <client-name> <domain>${NC}"
        exit 1
    fi
    
    if [ ! -f "$CLIENTS_DIR/$client_name/.env" ]; then
        echo -e "${RED}❌ Client '$client_name' not found${NC}"
        exit 1
    fi
    
    # Check if domain already exists
    if grep -q "CLIENT_DOMAIN_ALT.*=$new_domain" "$CLIENTS_DIR/$client_name/.env"; then
        echo -e "${YELLOW}⚠️  Domain '$new_domain' already exists for client '$client_name'${NC}"
        exit 1
    fi
    
    # Find next available slot
    if ! grep -q "CLIENT_DOMAIN_ALT1=" "$CLIENTS_DIR/$client_name/.env" || grep -q "CLIENT_DOMAIN_ALT1=$" "$CLIENTS_DIR/$client_name/.env"; then
        sed -i.bak "s/CLIENT_DOMAIN_ALT1=.*/CLIENT_DOMAIN_ALT1=$new_domain/" "$CLIENTS_DIR/$client_name/.env"
        echo -e "${GREEN}✅ Added '$new_domain' as ALT1 for client '$client_name'${NC}"
    elif ! grep -q "CLIENT_DOMAIN_ALT2=" "$CLIENTS_DIR/$client_name/.env" || grep -q "CLIENT_DOMAIN_ALT2=$" "$CLIENTS_DIR/$client_name/.env"; then
        sed -i.bak "s/CLIENT_DOMAIN_ALT2=.*/CLIENT_DOMAIN_ALT2=$new_domain/" "$CLIENTS_DIR/$client_name/.env"
        echo -e "${GREEN}✅ Added '$new_domain' as ALT2 for client '$client_name'${NC}"
    elif ! grep -q "CLIENT_DOMAIN_ALT3=" "$CLIENTS_DIR/$client_name/.env" || grep -q "CLIENT_DOMAIN_ALT3=$" "$CLIENTS_DIR/$client_name/.env"; then
        sed -i.bak "s/CLIENT_DOMAIN_ALT3=.*/CLIENT_DOMAIN_ALT3=$new_domain/" "$CLIENTS_DIR/$client_name/.env"
        echo -e "${GREEN}✅ Added '$new_domain' as ALT3 for client '$client_name'${NC}"
    else
        echo -e "${RED}❌ Client '$client_name' already has maximum domains (3 alternates)${NC}"
        exit 1
    fi
    
    rm "$CLIENTS_DIR/$client_name/.env.bak"
    
    # Update Traefik labels in compose file
    echo -e "${BLUE}🔄 Updating Traefik configuration...${NC}"
    # This would require regenerating the compose file with new domains
    echo -e "${YELLOW}⚠️  Please redeploy the client to apply domain changes: $0 deploy $client_name${NC}"
}

# Function to remove domain from client
remove_domain() {
    local client_name=$1
    local domain=$2
    
    if [ -z "$client_name" ] || [ -z "$domain" ]; then
        echo -e "${RED}❌ Usage: remove-domain <client-name> <domain>${NC}"
        exit 1
    fi
    
    if [ ! -f "$CLIENTS_DIR/$client_name/.env" ]; then
        echo -e "${RED}❌ Client '$client_name' not found${NC}"
        exit 1
    fi
    
    # Remove domain from environment file
    if grep -q "CLIENT_DOMAIN_ALT.*=$domain" "$CLIENTS_DIR/$client_name/.env"; then
        sed -i.bak "s/CLIENT_DOMAIN_ALT[123]=$domain/CLIENT_DOMAIN_ALT\1=/" "$CLIENTS_DIR/$client_name/.env"
        echo -e "${GREEN}✅ Removed '$domain' from client '$client_name'${NC}"
        rm "$CLIENTS_DIR/$client_name/.env.bak"
        echo -e "${YELLOW}⚠️  Please redeploy the client to apply changes: $0 deploy $client_name${NC}"
    else
        echo -e "${YELLOW}⚠️  Domain '$domain' not found for client '$client_name'${NC}"
    fi
}

# Function to list domains for client
list_domains() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Usage: list-domains <client-name>${NC}"
        exit 1
    fi
    
    if [ ! -f "$CLIENTS_DIR/$client_name/.env" ]; then
        echo -e "${RED}❌ Client '$client_name' not found${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🌐 Domains for client '$client_name':${NC}"
    echo ""
    
    # Load environment variables
    source "$CLIENTS_DIR/$client_name/.env"
    
    echo -e "  • Primary: ${CLIENT_DOMAIN}"
    [ -n "$CLIENT_DOMAIN_ALT1" ] && echo -e "  • Alt 1: ${CLIENT_DOMAIN_ALT1}"
    [ -n "$CLIENT_DOMAIN_ALT2" ] && echo -e "  • Alt 2: ${CLIENT_DOMAIN_ALT2}"
    [ -n "$CLIENT_DOMAIN_ALT3" ] && echo -e "  • Alt 3: ${CLIENT_DOMAIN_ALT3}"
}

# Function to deploy a client
deploy_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Usage: deploy <client-name>${NC}"
        exit 1
    fi
    
    if [ ! -d "$CLIENTS_DIR/$client_name" ]; then
        echo -e "${RED}❌ Client '$client_name' not found${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🚀 Deploying client: $client_name${NC}"
    
    # Load client environment
    if [ -f "$CLIENTS_DIR/$client_name/.env" ]; then
        source "$CLIENTS_DIR/$client_name/.env"
    else
        echo -e "${RED}❌ Client environment file not found${NC}"
        exit 1
    fi
    
    # Initialize WordPress if not already done
    if [ ! -f "$CLIENTS_DIR/$client_name/index.php" ]; then
        echo -e "${BLUE}📦 Initializing WordPress files...${NC}"
        if docker exec php-fpm-shared /bin/bash -c "/init-wordpress.sh $client_name" 2>/dev/null || ./scripts/init-wordpress.sh "$client_name"; then
            echo -e "${GREEN}✅ WordPress initialized${NC}"
        else
            echo -e "${YELLOW}⚠️  WordPress initialization failed${NC}"
        fi
    fi
    
    # Ensure Nginx config exists
    if [ ! -f "nginx/conf.d/${client_name}.conf" ]; then
        echo -e "${BLUE}🌐 Generating Nginx configuration...${NC}"
        ./scripts/update-nginx-config.sh "$client_name" "$CLIENT_DOMAIN" "$CLIENT_DOMAIN_ALT1" "$CLIENT_DOMAIN_ALT2" "$CLIENT_DOMAIN_ALT3"
    fi
    
    # Reload Nginx
    if docker ps | grep -q nginx-router; then
        echo -e "${BLUE}🔄 Reloading Nginx...${NC}"
        docker exec nginx-router nginx -t && docker exec nginx-router nginx -s reload
        echo -e "${GREEN}✅ Nginx reloaded${NC}"
    else
        echo -e "${YELLOW}⚠️  Nginx router not running. Please start base infrastructure: ./scripts/deploy-infrastructure.sh${NC}"
    fi
    
    echo -e "${GREEN}✅ Client '$client_name' deployed successfully!${NC}"
    echo -e "${BLUE}🌐 Access your site at: https://${CLIENT_DOMAIN}${NC}"
}

# Function to list all clients
list_clients() {
    echo -e "${BLUE}📋 Available Clients:${NC}"
    echo ""
    
    if [ ! -d "$CLIENTS_DIR" ]; then
        echo -e "${YELLOW}No clients found${NC}"
        return
    fi
    
    for client_dir in "$CLIENTS_DIR"/*; do
        if [ -d "$client_dir" ]; then
            client_name=$(basename "$client_dir")
            if [ -f "$client_dir/.env" ]; then
                source "$client_dir/.env"
                if [ -f "nginx/conf.d/${client_name}.conf" ]; then
                    status="${GREEN}● Configured${NC}"
                else
                    status="${YELLOW}● Pending Config${NC}"
                fi
                echo -e "  $client_name - $status (${CLIENT_DOMAIN})"
            fi
        fi
    done
}

# Function to show client status
show_status() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Usage: status <client-name>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📊 Client Status: $client_name${NC}"
    echo ""
    
    # Check client directory
    if [ -d "$CLIENTS_DIR/$client_name" ]; then
        echo -e "${GREEN}✅ Client directory exists${NC}"
        echo -e "  Path: $CLIENTS_DIR/$client_name"
        
        # Check Nginx config
        if [ -f "nginx/conf.d/${client_name}.conf" ]; then
            echo -e "${GREEN}✅ Nginx config exists${NC}"
        else
            echo -e "${YELLOW}⚠️  Nginx config missing${NC}"
        fi
        
        # Check WordPress files
        if [ -f "$CLIENTS_DIR/$client_name/index.php" ]; then
            echo -e "${GREEN}✅ WordPress files initialized${NC}"
        else
            echo -e "${YELLOW}⚠️  WordPress files not initialized${NC}"
        fi
        
        # Check database
        if docker ps | grep -q mariadb-shared; then
            if docker exec mariadb-shared mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "USE wordpress_${client_name};" 2>/dev/null; then
                echo -e "${GREEN}✅ Database exists${NC}"
            else
                echo -e "${YELLOW}⚠️  Database not found${NC}"
            fi
        else
            echo -e "${RED}❌ MariaDB shared service not running${NC}"
        fi
    else
        echo -e "${RED}❌ Client directory not found${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Shared Services Status:${NC}"
    docker ps --filter "name=nginx-router" --format "table {{.Names}}\t{{.Status}}"
    docker ps --filter "name=php-fpm-shared" --format "table {{.Names}}\t{{.Status}}"
    docker ps --filter "name=mariadb-shared" --format "table {{.Names}}\t{{.Status}}"
}

# Function to show client logs
show_logs() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Usage: logs <client-name>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📋 Client Logs: $client_name${NC}"
    echo ""
    echo -e "${YELLOW}Note: Clients use shared PHP-FPM and Nginx services${NC}"
    echo -e "${BLUE}Nginx Router Logs:${NC}"
    docker logs -f nginx-router 2>/dev/null || echo -e "${RED}Nginx router not running${NC}"
    echo ""
    echo -e "${BLUE}PHP-FPM Logs:${NC}"
    docker logs -f php-fpm-shared 2>/dev/null || echo -e "${RED}PHP-FPM service not running${NC}"
}

# Function to start a client
start_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Usage: start <client-name>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}▶️  Starting client: $client_name${NC}"
    
    if [ ! -d "$CLIENTS_DIR/$client_name" ]; then
        echo -e "${RED}❌ Client '$client_name' not found${NC}"
        exit 1
    fi
    
    # Reload Nginx to activate client
    if docker ps | grep -q nginx-router; then
        docker exec nginx-router nginx -s reload
        echo -e "${GREEN}✅ Client '$client_name' activated!${NC}"
    else
        echo -e "${YELLOW}⚠️  Nginx router not running. Please start base infrastructure.${NC}"
    fi
}

# Function to stop a client
stop_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Usage: stop <client-name>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}⏹️  Stopping client: $client_name${NC}"
    
    if [ ! -d "$CLIENTS_DIR/$client_name" ]; then
        echo -e "${RED}❌ Client '$client_name' not found${NC}"
        exit 1
    fi
    
    # Disable Nginx config
    if [ -f "nginx/conf.d/${client_name}.conf" ]; then
        mv "nginx/conf.d/${client_name}.conf" "nginx/conf.d/${client_name}.conf.disabled"
        if docker ps | grep -q nginx-router; then
            docker exec nginx-router nginx -s reload
        fi
        echo -e "${GREEN}✅ Client '$client_name' disabled!${NC}"
    else
        echo -e "${YELLOW}⚠️  Client '$client_name' is already disabled${NC}"
    fi
}

# Function to restart a client
restart_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Usage: restart <client-name>${NC}"
        exit 1
    fi
    
    stop_client "$client_name"
    start_client "$client_name"
}

# Function to remove a client
remove_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo -e "${RED}❌ Usage: remove <client-name>${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  Are you sure you want to remove client '$client_name'? (y/N)${NC}"
    read -r confirmation
    
    if [[ $confirmation =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🗑️  Removing client: $client_name${NC}"
        
        # Remove Nginx config
        rm -f "nginx/conf.d/${client_name}.conf"
        rm -f "nginx/conf.d/${client_name}.conf.disabled"
        
        # Reload Nginx if running
        if docker ps | grep -q nginx-router; then
            docker exec nginx-router nginx -s reload
        fi
        
        # Remove client directory and database
        rm -rf "$CLIENTS_DIR/$client_name"
        
        echo -e "${BLUE}🗄️  Database 'wordpress_${client_name}' still exists. Remove it manually if needed.${NC}"
        
        echo -e "${GREEN}✅ Client '$client_name' removed successfully!${NC}"
    else
        echo -e "${BLUE}ℹ️  Client removal cancelled${NC}"
    fi
}

# Main script logic
check_env

case "$1" in
    "create")
        create_client "$2" "$3" "$4" "$5" "$6"
        ;;
    "deploy")
        deploy_client "$2"
        ;;
    "start")
        start_client "$2"
        ;;
    "stop")
        stop_client "$2"
        ;;
    "restart")
        restart_client "$2"
        ;;
    "remove")
        remove_client "$2"
        ;;
    "list")
        list_clients
        ;;
    "status")
        show_status "$2"
        ;;
    "logs")
        show_logs "$2"
        ;;
    "backup")
        echo -e "${YELLOW}⚠️  Backup functionality not implemented yet${NC}"
        ;;
    "restore")
        echo -e "${YELLOW}⚠️  Restore functionality not implemented yet${NC}"
        ;;
    "update")
        echo -e "${YELLOW}⚠️  Update functionality not implemented yet${NC}"
        ;;
    "add-domain")
        add_domain "$2" "$3"
        ;;
    "remove-domain")
        remove_domain "$2" "$3"
        ;;
    "list-domains")
        list_domains "$2"
        ;;
    *)
        show_usage
        ;;
esac
