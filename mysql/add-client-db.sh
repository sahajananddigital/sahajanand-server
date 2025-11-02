#!/bin/bash

# Script to add a new client database and user to MySQL
# Usage: ./add-client-db.sh <client-name> [password]
# Example: ./add-client-db.sh client2 mypassword

if [ -z "$1" ]; then
    echo "Usage: $0 <client-name> [password]"
    echo "Example: $0 client2 mypassword"
    exit 1
fi

CLIENT_NAME="$1"
CLIENT_PASSWORD="${2:-${CLIENT_NAME}_password}"
CLIENT_DB="${CLIENT_NAME}_db"
CLIENT_USER="${CLIENT_NAME}_user"

# Load MySQL root password from .env if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | grep MYSQL_ROOT_PASSWORD | xargs)
fi

MYSQL_ROOT_PASS="${MYSQL_ROOT_PASSWORD:-rootpassword}"

echo "Adding database and user for client: $CLIENT_NAME"
echo "Database: $CLIENT_DB"
echo "User: $CLIENT_USER"

# Check if MySQL container is running
if ! docker ps | grep -q mysql; then
    echo "Error: MySQL container is not running"
    echo "Start it with: docker-compose up -d mysql"
    exit 1
fi

# Create SQL file
SQL_FILE="/tmp/add_${CLIENT_NAME}.sql"
cat > "$SQL_FILE" << EOF
CREATE DATABASE IF NOT EXISTS \`${CLIENT_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${CLIENT_USER}'@'%' IDENTIFIED BY '${CLIENT_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${CLIENT_DB}\`.* TO '${CLIENT_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Execute SQL
docker exec -i mysql mysql -u root -p"${MYSQL_ROOT_PASS}" < "$SQL_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Database and user created successfully!"
    echo ""
    echo "Connection details for ${CLIENT_NAME}:"
    echo "  Host: mysql"
    echo "  Database: ${CLIENT_DB}"
    echo "  Username: ${CLIENT_USER}"
    echo "  Password: ${CLIENT_PASSWORD}"
    echo ""
    echo "Add this to your client's .env or configuration:"
    echo "  DB_HOST=mysql"
    echo "  DB_DATABASE=${CLIENT_DB}"
    echo "  DB_USERNAME=${CLIENT_USER}"
    echo "  DB_PASSWORD=${CLIENT_PASSWORD}"
    
    # Clean up
    rm "$SQL_FILE"
else
    echo ""
    echo "✗ Error creating database. Check MySQL logs: docker logs mysql"
    rm "$SQL_FILE"
    exit 1
fi

