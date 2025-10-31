#!/bin/bash

# Create Client Database on Shared MariaDB
# This script is called by client-manager.sh to create databases on shared MariaDB

set -e

CLIENT_NAME=$1
DB_NAME="wordpress_${CLIENT_NAME}"
DB_USER="wordpress"

if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: create-client-db.sh <client-name>"
    exit 1
fi

# Load environment variables
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo "Error: MYSQL_ROOT_PASSWORD not set in .env"
    exit 1
fi

if [ -z "$MYSQL_PASSWORD" ]; then
    echo "Error: MYSQL_PASSWORD not set in .env"
    exit 1
fi

# Check if MariaDB is running
if ! docker ps | grep -q mariadb-shared; then
    echo "Error: mariadb-shared container is not running"
    echo "Please start the base infrastructure first: ./scripts/deploy-infrastructure.sh"
    exit 1
fi

# Create database
echo "Creating database: $DB_NAME"
docker exec -i mariadb-shared mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" << EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo "✅ Database '$DB_NAME' created successfully"
else
    echo "❌ Failed to create database '$DB_NAME'"
    exit 1
fi
