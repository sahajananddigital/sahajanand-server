#!/bin/bash

# WordPress Initialization Script for Shared PHP Service
# Copies shared WordPress files to client directory

set -e

CLIENT_NAME=$1
SHARED_WORDPRESS_DIR="/shared-wordpress"
CLIENT_WORDPRESS_DIR="/var/www/clients/${CLIENT_NAME}"

if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: $0 <client-name>"
    exit 1
fi

echo "Initializing WordPress for client: $CLIENT_NAME"

# Create client directory if it doesn't exist
mkdir -p "$CLIENT_WORDPRESS_DIR"

# Copy WordPress core files if not already present
if [ ! -f "$CLIENT_WORDPRESS_DIR/wp-config.php" ] && [ ! -f "$CLIENT_WORDPRESS_DIR/index.php" ]; then
    echo "Copying WordPress core files..."
    cp -r $SHARED_WORDPRESS_DIR/* $CLIENT_WORDPRESS_DIR/ 2>/dev/null || true
    
    # Set proper permissions
    chown -R www-data:www-data $CLIENT_WORDPRESS_DIR
    chmod -R 755 $CLIENT_WORDPRESS_DIR
    
    # Ensure uploads and backups directories exist and are writable
    mkdir -p $CLIENT_WORDPRESS_DIR/wp-content/uploads
    mkdir -p $CLIENT_WORDPRESS_DIR/wp-content/backups
    chown -R www-data:www-data $CLIENT_WORDPRESS_DIR/wp-content/uploads
    chown -R www-data:www-data $CLIENT_WORDPRESS_DIR/wp-content/backups
    chmod -R 775 $CLIENT_WORDPRESS_DIR/wp-content/uploads
    chmod -R 775 $CLIENT_WORDPRESS_DIR/wp-content/backups
fi

# Ensure mu-plugins directory exists
mkdir -p $CLIENT_WORDPRESS_DIR/wp-content/mu-plugins

# Copy shared mu-plugins
if [ -d "$SHARED_WORDPRESS_DIR/mu-plugins" ]; then
    echo "Copying shared mu-plugins..."
    cp -r $SHARED_WORDPRESS_DIR/mu-plugins/* $CLIENT_WORDPRESS_DIR/wp-content/mu-plugins/ 2>/dev/null || true
    chown -R www-data:www-data $CLIENT_WORDPRESS_DIR/wp-content/mu-plugins
    chmod -R 755 $CLIENT_WORDPRESS_DIR/wp-content/mu-plugins
fi

echo "WordPress initialization completed for client: $CLIENT_NAME"
