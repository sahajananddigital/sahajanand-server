#!/bin/bash

# Migration Script from HestiaCP to Docker-based WordPress Management
# This script helps migrate your existing HestiaCP WordPress sites

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HESTIA_USER="admin"  # Your HestiaCP username
HESTIA_BACKUP_DIR="/home/$HESTIA_USER/backup"
DOCKER_BACKUP_DIR="./backups/migration"

echo -e "${BLUE}=== HestiaCP to Docker Migration Script ===${NC}"
echo "This script will help you migrate your WordPress sites from HestiaCP"
echo

# Function to display help
show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  list-hestia-sites     List all WordPress sites in HestiaCP"
    echo "  backup-hestia-sites   Create backups of all HestiaCP sites"
    echo "  migrate-site <domain> Migrate a specific site"
    echo "  migrate-all           Migrate all WordPress sites"
    echo "  verify-migration      Verify migrated sites"
    echo "  help                  Show this help message"
    echo
}

# Function to list HestiaCP sites
list_hestia_sites() {
    echo -e "${YELLOW}WordPress Sites in HestiaCP:${NC}"
    echo
    
    # List web domains
    if [ -d "/home/$HESTIA_USER/web" ]; then
        for domain in /home/$HESTIA_USER/web/*; do
            if [ -d "$domain/public_html" ]; then
                domain_name=$(basename $domain)
                echo "Domain: $domain_name"
                
                # Check if it's WordPress
                if [ -f "$domain/public_html/wp-config.php" ]; then
                    echo "  Type: WordPress"
                    echo "  Path: $domain/public_html"
                    
                    # Get WordPress version
                    wp_version=$(grep "wp_version" "$domain/public_html/wp-includes/version.php" | cut -d"'" -f2)
                    echo "  Version: $wp_version"
                else
                    echo "  Type: Other"
                fi
                echo
            fi
        done
    else
        echo -e "${RED}HestiaCP web directory not found${NC}"
    fi
}

# Function to backup HestiaCP sites
backup_hestia_sites() {
    echo -e "${YELLOW}Creating backups of HestiaCP sites...${NC}"
    
    mkdir -p $DOCKER_BACKUP_DIR
    
    if [ -d "/home/$HESTIA_USER/web" ]; then
        for domain in /home/$HESTIA_USER/web/*; do
            if [ -d "$domain/public_html" ] && [ -f "$domain/public_html/wp-config.php" ]; then
                domain_name=$(basename $domain)
                echo -e "${YELLOW}Backing up $domain_name...${NC}"
                
                # Create domain backup directory
                mkdir -p "$DOCKER_BACKUP_DIR/$domain_name"
                
                # Backup files
                tar -czf "$DOCKER_BACKUP_DIR/$domain_name/files.tar.gz" -C "$domain/public_html" .
                
                # Backup database (if we can access it)
                if [ -f "$domain/public_html/wp-config.php" ]; then
                    # Extract database credentials
                    db_name=$(grep "DB_NAME" "$domain/public_html/wp-config.php" | cut -d"'" -f4)
                    db_user=$(grep "DB_USER" "$domain/public_html/wp-config.php" | cut -d"'" -f4)
                    db_pass=$(grep "DB_PASSWORD" "$domain/public_html/wp-config.php" | cut -d"'" -f4)
                    db_host=$(grep "DB_HOST" "$domain/public_html/wp-config.php" | cut -d"'" -f4)
                    
                    echo "  Database: $db_name"
                    echo "  User: $db_user"
                    echo "  Host: $db_host"
                    
                    # Try to backup database
                    if command -v mysqldump &> /dev/null; then
                        mysqldump -h "$db_host" -u "$db_user" -p"$db_pass" "$db_name" > "$DOCKER_BACKUP_DIR/$domain_name/database.sql"
                        echo "  Database backed up successfully"
                    else
                        echo "  Warning: mysqldump not found, database not backed up"
                    fi
                fi
                
                echo "  Files backed up successfully"
                echo
            fi
        done
    fi
    
    echo -e "${GREEN}Backup completed!${NC}"
    echo "Backup location: $DOCKER_BACKUP_DIR"
}

# Function to migrate a specific site
migrate_site() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain is required${NC}"
        echo "Usage: $0 migrate-site <domain>"
        exit 1
    fi
    
    echo -e "${YELLOW}Migrating site: $domain${NC}"
    
    # Check if backup exists
    if [ ! -d "$DOCKER_BACKUP_DIR/$domain" ]; then
        echo -e "${RED}Error: Backup not found for $domain${NC}"
        echo "Please run 'backup-hestia-sites' first"
        exit 1
    fi
    
    # Create site name from domain
    site_name=$(echo $domain | sed 's/\./_/g')
    
    # Add the site using site manager
    echo -e "${YELLOW}Adding site to Docker...${NC}"
    ./scripts/site-manager.sh add-site $domain $site_name
    
    # Wait for site to be ready
    sleep 10
    
    # Restore files
    echo -e "${YELLOW}Restoring files...${NC}"
    if [ -f "$DOCKER_BACKUP_DIR/$domain/files.tar.gz" ]; then
        docker run --rm -v wordpress_${site_name}_data:/data -v $(pwd)/$DOCKER_BACKUP_DIR/$domain:/backup alpine tar xzf /backup/files.tar.gz -C /data
    fi
    
    # Restore database
    echo -e "${YELLOW}Restoring database...${NC}"
    if [ -f "$DOCKER_BACKUP_DIR/$domain/database.sql" ]; then
        docker-compose exec -T mariadb mysql -u root -p${MYSQL_ROOT_PASSWORD} $site_name < "$DOCKER_BACKUP_DIR/$domain/database.sql"
    fi
    
    # Update WordPress configuration
    echo -e "${YELLOW}Updating WordPress configuration...${NC}"
    docker-compose exec wordpress-$site_name wp config set DB_HOST mariadb:3306 --allow-root
    docker-compose exec wordpress-$site_name wp config set DB_NAME $site_name --allow-root
    docker-compose exec wordpress-$site_name wp config set DB_USER wordpress --allow-root
    docker-compose exec wordpress-$site_name wp config set DB_PASSWORD ${MYSQL_PASSWORD} --allow-root
    
    # Update URLs
    echo -e "${YELLOW}Updating WordPress URLs...${NC}"
    docker-compose exec wordpress-$site_name wp search-replace "http://$domain" "https://$domain" --allow-root
    docker-compose exec wordpress-$site_name wp search-replace "https://$domain" "https://$domain" --allow-root
    
    # Clear cache
    docker-compose exec wordpress-$site_name wp cache flush --allow-root
    
    echo -e "${GREEN}Site $domain migrated successfully!${NC}"
    echo "Access: https://$domain"
}

# Function to migrate all sites
migrate_all() {
    echo -e "${YELLOW}Migrating all WordPress sites...${NC}"
    
    if [ -d "/home/$HESTIA_USER/web" ]; then
        for domain in /home/$HESTIA_USER/web/*; do
            if [ -d "$domain/public_html" ] && [ -f "$domain/public_html/wp-config.php" ]; then
                domain_name=$(basename $domain)
                echo -e "${YELLOW}Migrating $domain_name...${NC}"
                migrate_site $domain_name
                echo
            fi
        done
    fi
    
    echo -e "${GREEN}All sites migrated successfully!${NC}"
}

# Function to verify migration
verify_migration() {
    echo -e "${YELLOW}Verifying migrated sites...${NC}"
    
    # Check if sites are running
    echo -e "${YELLOW}Checking Docker containers:${NC}"
    docker-compose ps | grep wordpress
    
    echo
    echo -e "${YELLOW}Checking site accessibility:${NC}"
    
    # List all WordPress containers
    for container in $(docker ps --filter "name=wordpress-" --format "{{.Names}}"); do
        echo "Container: $container"
        
        # Check if container is healthy
        if docker-compose ps $container | grep -q "Up"; then
            echo "  Status: Running"
        else
            echo "  Status: Not running"
        fi
        
        # Check logs for errors
        echo "  Recent errors:"
        docker-compose logs --tail=5 $container | grep -i error || echo "    No errors found"
        echo
    done
}

# Main script logic
case "$1" in
    list-hestia-sites)
        list_hestia_sites
        ;;
    backup-hestia-sites)
        backup_hestia_sites
        ;;
    migrate-site)
        migrate_site "$2"
        ;;
    migrate-all)
        migrate_all
        ;;
    verify-migration)
        verify_migration
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo
        show_help
        exit 1
        ;;
esac

