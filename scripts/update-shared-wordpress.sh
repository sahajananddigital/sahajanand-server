#!/bin/bash

# Shared WordPress Update Script
# Updates shared WordPress files for all clients

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Updating Shared WordPress Files...${NC}"

# Check if we're in the right directory
if [ ! -f "wordpress/wp-config-shared.php" ]; then
    echo -e "${RED}❌ This script must be run from the project root directory${NC}"
    exit 1
fi

# Create a temporary WordPress container for updates
echo -e "${BLUE}🐳 Creating temporary WordPress container for updates...${NC}"
docker run -d --name wordpress-updater-temp \
    -v "$(pwd)/wordpress:/var/www/html" \
    -v "$(pwd)/scripts/update-scripts:/var/www/html/update-scripts:ro" \
    wordpress:6.4-php8.2-apache \
    tail -f /dev/null

# Wait for container to start
sleep 5

# Install WP-CLI
echo -e "${BLUE}🔧 Installing WP-CLI...${NC}"
docker exec wordpress-updater-temp bash -c "
    curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
    wp --info
"

# Update WordPress core
echo -e "${BLUE}⬆️  Updating WordPress core...${NC}"
docker exec wordpress-updater-temp wp core download --force --allow-root

# Update shared plugins (if any)
echo -e "${BLUE}🔌 Updating shared plugins...${NC}"
if [ -d "wordpress/wp-content/plugins" ]; then
    docker exec wordpress-updater-temp wp plugin update --all --allow-root
fi

# Update shared themes (if any)
echo -e "${BLUE}🎨 Updating shared themes...${NC}"
if [ -d "wordpress/wp-content/themes" ]; then
    docker exec wordpress-updater-temp wp theme update --all --allow-root
fi

# Update mu-plugins
echo -e "${BLUE}🔧 Updating mu-plugins...${NC}"
# The mu-plugins are already in the shared directory and will be updated via Git

# Set proper permissions
echo -e "${BLUE}🔐 Setting proper permissions...${NC}"
docker exec wordpress-updater-temp chown -R www-data:www-data /var/www/html
docker exec wordpress-updater-temp chmod -R 755 /var/www/html
docker exec wordpress-updater-temp chmod -R 777 /var/www/html/wp-content/uploads

# Clean up temporary container
echo -e "${BLUE}🧹 Cleaning up...${NC}"
docker stop wordpress-updater-temp
docker rm wordpress-updater-temp

# Show updated information
echo -e "${GREEN}✅ Shared WordPress files updated successfully!${NC}"
echo -e "${BLUE}📋 Updated Components:${NC}"
echo -e "  • WordPress Core: $(docker run --rm wordpress:6.4-php8.2-apache wp core version --allow-root 2>/dev/null || echo 'Unknown')"
echo -e "  • Mu-plugins: Updated via Git"
echo -e "  • Shared themes: Updated"
echo -e "  • Shared plugins: Updated"

echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "  1. Commit changes to Git: git add wordpress/ && git commit -m 'Update shared WordPress files'"
echo -e "  2. Reload Nginx: docker exec nginx-router nginx -s reload"
echo -e "  3. Test client sites to ensure everything works"
echo -e "${BLUE}ℹ️  Note: Clients automatically use updated WordPress files${NC}"
