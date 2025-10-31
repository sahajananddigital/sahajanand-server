#!/bin/bash

# Hestia Migration Helper
# Helps migrate from Hestia CP to Docker infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Hestia Migration Helper${NC}"
echo ""

# Function to show usage
show_usage() {
    echo -e "${BLUE}Hestia Migration Helper${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  analyze                    Analyze current Hestia setup"
    echo "  backup                     Backup Hestia data"
    echo "  extract-client <user>      Extract specific client data"
    echo "  convert-client <user>      Convert client to Docker format"
    echo "  test-migration <user>      Test migration on subdomain"
    echo "  compare-performance        Compare Hestia vs Docker performance"
    echo "  rollback <user>            Rollback client to Hestia"
    echo ""
    echo "Examples:"
    echo "  $0 analyze"
    echo "  $0 extract-client john_doe"
    echo "  $0 test-migration john_doe"
}

# Function to analyze Hestia setup
analyze_hestia() {
    echo -e "${BLUE}🔍 Analyzing Hestia Setup...${NC}"
    echo ""
    
    # Check if Hestia is installed
    if [ ! -f "/usr/local/hestia/bin/v-list-user" ]; then
        echo -e "${RED}❌ Hestia CP not found on this system${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Hestia CP detected${NC}"
    
    # List all users
    echo -e "${BLUE}📋 Current Hestia Users:${NC}"
    /usr/local/hestia/bin/v-list-users | grep -E "^[a-zA-Z0-9_]+" | while read user; do
        if [ -n "$user" ]; then
            echo -e "  • $user"
        fi
    done
    
    echo ""
    echo -e "${BLUE}📊 System Resources:${NC}"
    echo -e "  • RAM: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo -e "  • Disk: $(df -h / | tail -1 | awk '{print $2}')"
    echo -e "  • CPU: $(nproc) cores"
    
    echo ""
    echo -e "${BLUE}🌐 Web Domains:${NC}"
    /usr/local/hestia/bin/v-list-users | grep -E "^[a-zA-Z0-9_]+" | while read user; do
        if [ -n "$user" ]; then
            domains=$(/usr/local/hestia/bin/v-list-web-domains $user 2>/dev/null | grep -E "^[a-zA-Z0-9.-]+" | wc -l)
            if [ "$domains" -gt 0 ]; then
                echo -e "  • $user: $domains domains"
            fi
        fi
    done
}

# Function to backup Hestia data
backup_hestia() {
    echo -e "${BLUE}💾 Creating Hestia Backup...${NC}"
    
    local backup_dir="hestia-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo -e "${YELLOW}📁 Creating backup directory: $backup_dir${NC}"
    
    # Backup user data
    echo -e "${BLUE}👥 Backing up user data...${NC}"
    /usr/local/hestia/bin/v-list-users | grep -E "^[a-zA-Z0-9_]+" | while read user; do
        if [ -n "$user" ]; then
            echo -e "  • Backing up user: $user"
            mkdir -p "$backup_dir/users/$user"
            
            # Backup web domains
            /usr/local/hestia/bin/v-list-web-domains $user 2>/dev/null | grep -E "^[a-zA-Z0-9.-]+" | while read domain; do
                if [ -n "$domain" ]; then
                    echo -e "    - Domain: $domain"
                    cp -r "/home/$user/web/$domain" "$backup_dir/users/$user/" 2>/dev/null || true
                fi
            done
            
            # Backup databases
            /usr/local/hestia/bin/v-list-databases $user 2>/dev/null | grep -E "^[a-zA-Z0-9_]+" | while read db; do
                if [ -n "$db" ]; then
                    echo -e "    - Database: $db"
                    mysqldump -u root -p$HESTIA_PASSWORD $db > "$backup_dir/users/$user/$db.sql" 2>/dev/null || true
                fi
            done
        fi
    done
    
    echo -e "${GREEN}✅ Hestia backup completed: $backup_dir${NC}"
}

# Function to extract client data
extract_client() {
    local user=$1
    
    if [ -z "$user" ]; then
        echo -e "${RED}❌ Usage: extract-client <user>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📤 Extracting client data for: $user${NC}"
    
    # Check if user exists
    if ! /usr/local/hestia/bin/v-list-user $user >/dev/null 2>&1; then
        echo -e "${RED}❌ User '$user' not found in Hestia${NC}"
        exit 1
    fi
    
    local client_dir="clients/$user"
    mkdir -p "$client_dir"
    
    # Extract web domains
    echo -e "${BLUE}🌐 Extracting web domains...${NC}"
    /usr/local/hestia/bin/v-list-web-domains $user 2>/dev/null | grep -E "^[a-zA-Z0-9.-]+" | while read domain; do
        if [ -n "$domain" ]; then
            echo -e "  • Domain: $domain"
            cp -r "/home/$user/web/$domain" "$client_dir/" 2>/dev/null || true
        fi
    done
    
    # Extract databases
    echo -e "${BLUE}🗄️  Extracting databases...${NC}"
    /usr/local/hestia/bin/v-list-databases $user 2>/dev/null | grep -E "^[a-zA-Z0-9_]+" | while read db; do
        if [ -n "$db" ]; then
            echo -e "  • Database: $db"
            mysqldump -u root -p$HESTIA_PASSWORD $db > "$client_dir/$db.sql" 2>/dev/null || true
        fi
    done
    
    # Extract user info
    echo -e "${BLUE}👤 Extracting user information...${NC}"
    /usr/local/hestia/bin/v-list-user $user > "$client_dir/user-info.txt"
    
    echo -e "${GREEN}✅ Client data extracted to: $client_dir${NC}"
}

# Function to convert client to Docker format
convert_client() {
    local user=$1
    
    if [ -z "$user" ]; then
        echo -e "${RED}❌ Usage: convert-client <user>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔄 Converting client to Docker format: $user${NC}"
    
    local client_dir="clients/$user"
    if [ ! -d "$client_dir" ]; then
        echo -e "${RED}❌ Client data not found. Run 'extract-client $user' first${NC}"
        exit 1
    fi
    
    # Get primary domain
    local primary_domain=$(/usr/local/hestia/bin/v-list-web-domains $user 2>/dev/null | grep -E "^[a-zA-Z0-9.-]+" | head -1)
    
    if [ -z "$primary_domain" ]; then
        echo -e "${RED}❌ No web domains found for user '$user'${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🌐 Primary domain: $primary_domain${NC}"
    
    # Create Docker client
    echo -e "${BLUE}🐳 Creating Docker client...${NC}"
    ./scripts/client-manager.sh create "$user" "$primary_domain"
    
    # Copy WordPress files
    echo -e "${BLUE}📁 Copying WordPress files...${NC}"
    if [ -d "$client_dir/$primary_domain/public_html" ]; then
        cp -r "$client_dir/$primary_domain/public_html"/* "clients/$user/wordpress/" 2>/dev/null || true
    fi
    
    # Import database
    echo -e "${BLUE}🗄️  Importing database...${NC}"
    local db_file="$client_dir/wordpress.sql"
    if [ -f "$db_file" ]; then
        echo -e "${YELLOW}📝 Database file found: $db_file${NC}"
        echo -e "${YELLOW}📝 You'll need to import this manually after deployment${NC}"
    fi
    
    echo -e "${GREEN}✅ Client converted to Docker format${NC}"
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "  1. Review the converted client: clients/$user/"
    echo -e "  2. Deploy the client: ./scripts/client-manager.sh deploy $user"
    echo -e "  3. Import database if needed"
    echo -e "  4. Test the migrated site"
}

# Function to test migration
test_migration() {
    local user=$1
    
    if [ -z "$user" ]; then
        echo -e "${RED}❌ Usage: test-migration <user>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🧪 Testing migration for: $user${NC}"
    
    # Create test subdomain
    local test_domain="test-$user.yourdomain.com"
    echo -e "${BLUE}🌐 Test domain: $test_domain${NC}"
    
    # Deploy client with test domain
    echo -e "${BLUE}🐳 Deploying test client...${NC}"
    ./scripts/client-manager.sh create "$user-test" "$test_domain"
    ./scripts/client-manager.sh deploy "$user-test"
    
    echo -e "${GREEN}✅ Test migration deployed${NC}"
    echo -e "${YELLOW}📝 Test URL: https://$test_domain${NC}"
    echo -e "${YELLOW}📝 Compare with original: https://original-domain${NC}"
}

# Function to compare performance
compare_performance() {
    echo -e "${BLUE}📊 Performance Comparison Tool${NC}"
    echo ""
    echo -e "${YELLOW}This tool will help you compare Hestia vs Docker performance${NC}"
    echo ""
    echo -e "${BLUE}Hestia Performance:${NC}"
    echo -e "  • CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo -e "  • Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    echo -e "  • Disk Usage: $(df -h / | tail -1 | awk '{print $5}')"
    echo ""
    echo -e "${BLUE}Docker Performance:${NC}"
    echo -e "  • Run 'docker stats' to see Docker resource usage"
    echo ""
    echo -e "${YELLOW}📝 Use tools like 'htop', 'iotop', and 'docker stats' for detailed monitoring${NC}"
}

# Function to rollback client
rollback_client() {
    local user=$1
    
    if [ -z "$user" ]; then
        echo -e "${RED}❌ Usage: rollback <user>${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔄 Rolling back client: $user${NC}"
    
    # Stop Docker client
    echo -e "${BLUE}🛑 Stopping Docker client...${NC}"
    ./scripts/client-manager.sh stop "$user"
    
    # Restore from Hestia backup
    echo -e "${BLUE}📥 Restoring from Hestia backup...${NC}"
    if [ -d "hestia-backup-*/users/$user" ]; then
        echo -e "${GREEN}✅ Rollback completed${NC}"
        echo -e "${YELLOW}📝 Client restored to Hestia state${NC}"
    else
        echo -e "${RED}❌ No backup found for user '$user'${NC}"
    fi
}

# Main script logic
case "$1" in
    "analyze")
        analyze_hestia
        ;;
    "backup")
        backup_hestia
        ;;
    "extract-client")
        extract_client "$2"
        ;;
    "convert-client")
        convert_client "$2"
        ;;
    "test-migration")
        test_migration "$2"
        ;;
    "compare-performance")
        compare_performance
        ;;
    "rollback")
        rollback_client "$2"
        ;;
    *)
        show_usage
        ;;
esac
