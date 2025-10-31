#!/bin/bash

# Test Setup Script
# Verifies that the infrastructure setup will work

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Testing Infrastructure Setup...${NC}"

# Test 1: Check required files
echo -e "${BLUE}📁 Checking required files...${NC}"
required_files=(
    "docker-compose.base.yml"
    "wordpress/wp-config-shared.php"
    "wordpress/mu-plugins/object-cache.php"
    "wordpress/mu-plugins/client-manager.php"
    "wordpress/mu-plugins/update-manager.php"
    "scripts/client-manager.sh"
    "scripts/deploy-infrastructure.sh"
    "scripts/init-wordpress.sh"
    "env.example"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${RED}❌ $file - MISSING${NC}"
        exit 1
    fi
done

# Test 2: Check Docker Compose syntax
echo -e "${BLUE}🐳 Checking Docker Compose syntax...${NC}"
if docker-compose -f docker-compose.base.yml config > /dev/null 2>&1; then
    echo -e "${GREEN}✅ docker-compose.base.yml syntax OK${NC}"
else
    echo -e "${RED}❌ docker-compose.base.yml syntax ERROR${NC}"
    exit 1
fi

# Test 3: Check PHP syntax
echo -e "${BLUE}🐘 Checking PHP syntax...${NC}"
if php -l wordpress/wp-config-shared.php > /dev/null 2>&1; then
    echo -e "${GREEN}✅ wp-config-shared.php syntax OK${NC}"
else
    echo -e "${RED}❌ wp-config-shared.php syntax ERROR${NC}"
    exit 1
fi

for plugin in wordpress/mu-plugins/*.php; do
    if [ -f "$plugin" ]; then
        if php -l "$plugin" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $(basename $plugin) syntax OK${NC}"
        else
            echo -e "${RED}❌ $(basename $plugin) syntax ERROR${NC}"
            exit 1
        fi
    fi
done

# Test 4: Check script permissions
echo -e "${BLUE}🔐 Checking script permissions...${NC}"
scripts=(
    "scripts/client-manager.sh"
    "scripts/deploy-infrastructure.sh"
    "scripts/init-wordpress.sh"
    "scripts/test-setup.sh"
)

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo -e "${GREEN}✅ $script is executable${NC}"
    else
        echo -e "${YELLOW}⚠️  $script is not executable, fixing...${NC}"
        chmod +x "$script"
        echo -e "${GREEN}✅ $script is now executable${NC}"
    fi
done

# Test 5: Check directory structure
echo -e "${BLUE}📂 Checking directory structure...${NC}"
directories=(
    "wordpress"
    "wordpress/mu-plugins"
    "wordpress/themes"
    "wordpress/uploads"
    "wordpress/backups"
    "clients"
    "scripts"
    "traefik"
    "mysql"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅ $dir/ exists${NC}"
    else
        echo -e "${YELLOW}⚠️  $dir/ missing, creating...${NC}"
        mkdir -p "$dir"
        echo -e "${GREEN}✅ $dir/ created${NC}"
    fi
done

# Test 6: Check environment file
echo -e "${BLUE}⚙️  Checking environment configuration...${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ .env file exists${NC}"
    
    # Check required variables
    required_vars=("BASE_DOMAIN" "MYSQL_ROOT_PASSWORD" "MYSQL_PASSWORD" "EMAIL")
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" .env; then
            echo -e "${GREEN}✅ $var is set${NC}"
        else
            echo -e "${YELLOW}⚠️  $var is not set in .env${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  .env file not found, copying from template...${NC}"
    cp env.example .env
    echo -e "${GREEN}✅ .env file created from template${NC}"
    echo -e "${YELLOW}📝 Please edit .env file with your configuration${NC}"
fi

# Test 7: Resource estimation
echo -e "${BLUE}📊 Resource estimation...${NC}"
echo -e "${YELLOW}Base Infrastructure (Shared Services):${NC}"
echo -e "  • Traefik: ~128MB RAM"
echo -e "  • Portainer: ~128MB RAM"
echo -e "  • Watchtower: ~64MB RAM"
echo -e "  • MariaDB Shared: ~768MB RAM"
echo -e "  • Redis Shared: ~320MB RAM"
echo -e "  • PHP-FPM Shared: ~512MB RAM"
echo -e "  • Nginx Router: ~128MB RAM"
echo -e "  • Total Base: ~2GB RAM"
echo ""
echo -e "${YELLOW}Per Client:${NC}"
echo -e "  • No individual containers needed!"
echo -e "  • 0MB RAM per client (just directories + configs)"
echo ""
echo -e "${YELLOW}For 4GB ARM Server:${NC}"
echo -e "  • Can handle: 50+ clients"
echo -e "  • Total estimated usage: ~2GB RAM (base only)"

echo -e "${GREEN}🎉 Setup test completed successfully!${NC}"
echo -e "${BLUE}📝 Next steps:${NC}"
echo -e "  1. Edit .env file with your configuration"
echo -e "  2. Deploy infrastructure: ./scripts/deploy-infrastructure.sh"
echo -e "  3. Create first client: ./scripts/client-manager.sh create test-client test.com"
echo -e "  4. Deploy client: ./scripts/client-manager.sh deploy test-client"
