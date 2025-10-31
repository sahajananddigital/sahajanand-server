#!/bin/bash

# Update Nginx Configuration for Client
# Generates Nginx config for a client based on template

set -e

CLIENT_NAME=$1
CLIENT_DOMAIN=$2
CLIENT_DOMAIN_ALT1=${3:-}
CLIENT_DOMAIN_ALT2=${4:-}
CLIENT_DOMAIN_ALT3=${5:-}

if [ -z "$CLIENT_NAME" ] || [ -z "$CLIENT_DOMAIN" ]; then
    echo "Usage: update-nginx-config.sh <client-name> <domain> [alt1] [alt2] [alt3]"
    exit 1
fi

NGINX_CONF_DIR="nginx/conf.d"
TEMPLATE_FILE="nginx/client-template.conf"
OUTPUT_FILE="$NGINX_CONF_DIR/${CLIENT_NAME}.conf"

# Create conf.d directory if it doesn't exist
mkdir -p "$NGINX_CONF_DIR"

# Generate Nginx config from template
sed -e "s|\${CLIENT_NAME}|$CLIENT_NAME|g" \
    -e "s|\${CLIENT_DOMAIN}|$CLIENT_DOMAIN|g" \
    -e "s|\${CLIENT_DOMAIN_ALT1}|${CLIENT_DOMAIN_ALT1:-}|g" \
    -e "s|\${CLIENT_DOMAIN_ALT2}|${CLIENT_DOMAIN_ALT2:-}|g" \
    -e "s|\${CLIENT_DOMAIN_ALT3}|${CLIENT_DOMAIN_ALT3:-}|g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "✅ Nginx config created: $OUTPUT_FILE"

# Reload Nginx if container is running
if docker ps | grep -q nginx-router; then
    echo "🔄 Reloading Nginx..."
    docker exec nginx-router nginx -t && docker exec nginx-router nginx -s reload
    echo "✅ Nginx reloaded"
else
    echo "⚠️  Nginx router not running. Config will be loaded on next start."
fi
