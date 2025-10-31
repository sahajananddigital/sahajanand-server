#!/bin/bash

# Infrastructure Deployment Script
# Deploys the base infrastructure for client management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏗️  Deploying Base Infrastructure...${NC}"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}📋 Copying environment template...${NC}"
    cp env.example .env
    echo -e "${YELLOW}⚠️  Please edit .env file with your actual configuration before continuing${NC}"
    read -p "Press Enter after updating .env file..."
fi

# Create necessary directories
echo -e "${BLUE}📁 Creating necessary directories...${NC}"
mkdir -p ssl logs/traefik mysql/conf.d clients

# Set proper permissions
chmod 755 ssl logs mysql clients
chmod 644 mysql/my.cnf

# Create networks
echo -e "${BLUE}🌐 Creating Docker networks...${NC}"
docker network create web 2>/dev/null || true
docker network create internal 2>/dev/null || true

# Deploy base infrastructure
echo -e "${BLUE}🚀 Deploying base infrastructure...${NC}"
docker-compose -f docker-compose.base.yml --env-file .env up -d

# Wait for services to be ready
echo -e "${BLUE}⏳ Waiting for services to start...${NC}"
sleep 10

# Check service health
echo -e "${BLUE}🔍 Checking service health...${NC}"
docker-compose -f docker-compose.base.yml --env-file .env ps

# Display resource usage
echo -e "${BLUE}📊 Current resource usage:${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Display access information
echo -e "${GREEN}✅ Base infrastructure deployed successfully!${NC}"
echo -e "${BLUE}📋 Access Information:${NC}"
echo -e "  • Traefik Dashboard: http://your-server-ip:8080"
echo -e "  • Portainer: https://admin.$(grep BASE_DOMAIN .env | cut -d'=' -f2)"

echo -e "${BLUE}🔧 Client Management Commands:${NC}"
echo -e "  • Create client: ./scripts/client-manager.sh create client-name domain.com"
echo -e "  • List clients: ./scripts/client-manager.sh list"
echo -e "  • Deploy client: ./scripts/client-manager.sh deploy client-name"

echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "  1. Create your first client: ./scripts/client-manager.sh create acme-corp acme.com"
echo -e "  2. Deploy the client: ./scripts/client-manager.sh deploy acme-corp"
echo -e "  3. Add client files to Git for tracking"
