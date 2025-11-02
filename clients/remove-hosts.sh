#!/bin/bash

# Script to remove host entries for local development
# Usage: ./remove-hosts.sh

echo "Removing host entries for PHP clients from /etc/hosts..."

# Check if entries exist
if ! grep -q "sahajanand-server-infrastructure clients" /etc/hosts 2>/dev/null; then
    echo "No host entries found."
    exit 0
fi

# Remove entries
sudo sed -i.bak '/# sahajanand-server-infrastructure clients/,/# End sahajanand-server-infrastructure clients/d' /etc/hosts

echo "Host entries removed successfully!"

