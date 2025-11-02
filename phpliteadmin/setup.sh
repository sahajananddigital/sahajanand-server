#!/bin/bash

# phpLiteAdmin Setup Script
# Downloads and configures phpLiteAdmin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Setting up phpLiteAdmin..."

# Download phpLiteAdmin
if [ ! -f "phpliteadmin.php" ]; then
    echo "Downloading phpLiteAdmin..."
    echo "Trying official website..."
    curl -L -o phpliteadmin.php https://www.phpliteadmin.org/phpliteadmin.php
    
    if [ $? -eq 0 ] && [ -s "phpliteadmin.php" ] && head -50 phpliteadmin.php | grep -q "phpLiteAdmin\|php"; then
        echo "✓ phpLiteAdmin downloaded successfully"
    else
        echo "✗ Failed to download from official site"
        echo "Trying GitHub releases..."
        curl -L -o phpliteadmin.php https://github.com/ovity/phpliteadmin/raw/master/phpliteadmin.php
        if [ $? -eq 0 ] && [ -s "phpliteadmin.php" ]; then
            echo "✓ phpLiteAdmin downloaded successfully"
        else
            echo "✗ Failed to download automatically"
            echo ""
            echo "Please download phpLiteAdmin manually:"
            echo "  1. Visit: https://www.phpliteadmin.org/download/"
            echo "  2. Download phpliteadmin.php"
            echo "  3. Place it in this directory: $(pwd)"
            exit 1
        fi
    fi
else
    echo "phpLiteAdmin already exists, skipping download"
fi

# Check if password is set
if grep -q "\$password = '';" phpliteadmin.php; then
    echo ""
    echo "⚠ WARNING: phpLiteAdmin is using the default empty password!"
    echo ""
    echo "Please set a secure password by editing phpliteadmin.php:"
    echo "  Search for: \$password = '';"
    echo "  Change to: \$password = 'your-secure-password';"
    echo ""
else
    echo "✓ Password appears to be configured"
fi

# Configure to allow subdirectories (for accessing client databases)
if grep -q "\$subdirectories = false;" phpliteadmin.php; then
    echo "Enabling subdirectory browsing..."
    sed -i.bak 's/\$subdirectories = false;/\$subdirectories = true;/' phpliteadmin.php
    echo "✓ Subdirectory browsing enabled"
fi

echo ""
echo "Setup complete!"
echo ""
echo "To access client SQLite databases, navigate to:"
echo "  /clients/client1/database/"
echo "  /clients/client2/database/"
echo ""
echo "Don't forget to set a secure password in phpliteadmin.php"

