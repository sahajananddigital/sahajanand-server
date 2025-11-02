#!/bin/bash

# Script to set up Web UI authentication
# This creates or updates the .webui_auth file with secure credentials

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTH_FILE="$PROJECT_ROOT/.webui_auth"

echo "Web UI Authentication Setup"
echo "=========================="
echo ""

# Check if auth file exists
if [ -f "$AUTH_FILE" ]; then
    echo "Warning: .webui_auth file already exists."
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Get username
read -p "Enter username: " username
if [ -z "$username" ]; then
    echo "Error: Username cannot be empty"
    exit 1
fi

# Get password
read -sp "Enter password: " password
echo
if [ -z "$password" ]; then
    echo "Error: Password cannot be empty"
    exit 1
fi

# Confirm password
read -sp "Confirm password: " password_confirm
echo
if [ "$password" != "$password_confirm" ]; then
    echo "Error: Passwords do not match"
    exit 1
fi

# Check if password is strong enough
if [ ${#password} -lt 8 ]; then
    echo "Warning: Password is less than 8 characters. Consider using a stronger password."
fi

# Generate password hash
if command -v php &> /dev/null; then
    PASSWORD_HASH=$(php -r "echo password_hash('$password', PASSWORD_DEFAULT);")
else
    echo "Error: PHP is not installed. Cannot generate password hash."
    echo "Install PHP or manually create .webui_auth with a password hash."
    exit 1
fi

# Create auth file
cat > "$AUTH_FILE" << EOF
WEBUI_USERNAME=$username
WEBUI_PASSWORD_HASH=$PASSWORD_HASH
EOF

# Set secure permissions
chmod 600 "$AUTH_FILE"

echo ""
echo "✓ Authentication file created successfully!"
echo ""
echo "File location: $AUTH_FILE"
echo "Username: $username"
echo ""
echo "⚠️  IMPORTANT:"
echo "1. Keep this file secure and never commit it to version control"
echo "2. Add .webui_auth to your .gitignore file"
echo "3. Backup this file securely"
echo "4. In production, ensure only authorized users have access"
echo ""

