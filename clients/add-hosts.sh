#!/bin/bash

# Script to add host entries for local development
# Usage: ./add-hosts.sh [server-ip]
# Example: ./add-hosts.sh 127.0.0.1

SERVER_IP="${1:-127.0.0.1}"

echo "Adding host entries for PHP clients to /etc/hosts..."
echo "Server IP: $SERVER_IP"
echo ""

# Find all client docker-compose.yml files and extract hostnames
CLIENTS_DIR="$(dirname "$0")"
HOST_ENTRIES=""

# Find client hostnames
while IFS= read -r -d '' compose_file; do
    # Extract hostname from Traefik labels (compatible with macOS)
    HOST_LINE=$(grep "Host(\`" "$compose_file" | head -1)
    if [ ! -z "$HOST_LINE" ]; then
        HOST=$(echo "$HOST_LINE" | sed -E "s/.*Host\(\\\`([^\\\`]+)\\\`.*/\1/")
        if [ ! -z "$HOST" ] && [ "$HOST" != "$HOST_LINE" ]; then
            HOST_ENTRIES="$HOST_ENTRIES\n$SERVER_IP $HOST"
            echo "Found: $HOST"
        fi
    fi
done < <(find "$CLIENTS_DIR" -name "docker-compose.yml" -type f -print0)

# Add admin tools
PROJECT_ROOT="$(cd "$CLIENTS_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    # Check for phpMyAdmin
    if grep -q "phpmyadmin" "$PROJECT_ROOT/docker-compose.yml"; then
        PMA_HOST=$(grep "phpmyadmin.*Host" "$PROJECT_ROOT/docker-compose.yml" | sed -E "s/.*Host\(\\\`([^\\\`]+)\\\`.*/\1/" | head -1)
        if [ ! -z "$PMA_HOST" ]; then
            HOST_ENTRIES="$HOST_ENTRIES\n$SERVER_IP $PMA_HOST"
            echo "Found: $PMA_HOST (phpMyAdmin)"
        fi
    fi
    # Check for phpLiteAdmin
    if grep -q "phpliteadmin.*Host" "$PROJECT_ROOT/docker-compose.yml"; then
        PLA_HOST=$(grep "phpliteadmin.*Host" "$PROJECT_ROOT/docker-compose.yml" | sed -E "s/.*Host\(\\\`([^\\\`]+)\\\`.*/\1/" | head -1)
        if [ ! -z "$PLA_HOST" ]; then
            HOST_ENTRIES="$HOST_ENTRIES\n$SERVER_IP $PLA_HOST"
            echo "Found: $PLA_HOST (phpLiteAdmin)"
        fi
    fi
fi

if [ -z "$HOST_ENTRIES" ]; then
    echo "No client hostnames found."
    exit 1
fi

# Check if entries already exist
if grep -q "sahajanand-server-infrastructure clients" /etc/hosts 2>/dev/null; then
    echo ""
    echo "Host entries already exist. Updating..."
    # Remove old entries
    sudo sed -i.bak '/# sahajanand-server-infrastructure clients/,/# End sahajanand-server-infrastructure clients/d' /etc/hosts
fi

# Add new entries
echo -e "\n# sahajanand-server-infrastructure clients" | sudo tee -a /etc/hosts > /dev/null
echo -e "$HOST_ENTRIES" | sudo tee -a /etc/hosts > /dev/null
echo "# End sahajanand-server-infrastructure clients" | sudo tee -a /etc/hosts > /dev/null

echo ""
echo "Host entries added successfully!"
echo ""
echo "Current entries:"
grep "sahajanand-server-infrastructure clients" -A 100 /etc/hosts | grep -v "^--$" | tail -n +2 | head -n -1

