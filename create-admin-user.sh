#!/bin/bash

# Script to create a non-root admin user on Linux systems
# Must be run as root

set -euo pipefail

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 1. Enforce run as root
if [ "$EUID" -ne 0 ] && [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root."
    exit 1
fi

echo "=================================================================="
echo "          VPS Non-Root Admin User Creation Script                 "
echo "=================================================================="
echo ""

# Get username
DEFAULT_USER="vpsadmin"
read -p "Enter username for the new admin [default: $DEFAULT_USER]: " username
username="${username:-$DEFAULT_USER}"

# Validate username format
if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    log_error "Invalid username format. Use only lowercase letters, numbers, hyphens, and underscores."
    exit 1
fi

# Check if user already exists
if id "$username" &>/dev/null; then
    log_error "User '$username' already exists."
    exit 1
fi

# Generate random secure password
password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)

log_info "Creating user '$username'..."
useradd -m -s /bin/bash "$username"

log_info "Setting password..."
echo "$username:$password" | chpasswd

# Determine standard sudo group
if grep -q '^sudo:' /etc/group; then
    SUDO_GROUP="sudo"
elif grep -q '^wheel:' /etc/group; then
    SUDO_GROUP="wheel"
else
    # Create sudo group if not exists
    groupadd sudo || true
    SUDO_GROUP="sudo"
fi

log_info "Adding '$username' to group '$SUDO_GROUP'..."
usermod -aG "$SUDO_GROUP" "$username"

# Copy root SSH keys to preserve SSH access
log_info "Copying root authorized_keys to '$username'..."
if [ -d /root/.ssh ]; then
    mkdir -p "/home/$username/.ssh"
    cp -r /root/.ssh/* "/home/$username/.ssh/" 2>/dev/null || true
    chown -R "$username:$username" "/home/$username/.ssh"
    chmod 700 "/home/$username/.ssh"
    chmod 600 "/home/$username/.ssh"/* 2>/dev/null || true
    log_success "SSH keys copied successfully."
else
    log_warn "No SSH keys found in /root/.ssh. Make sure to configure SSH keys for '$username' later."
fi

# Save credentials to credentials-system.txt
CREDENTIALS_FILE="credentials-system.txt"
cat > "$CREDENTIALS_FILE" << EOF
==================================================================
        SAHAJANAND SERVER SYSTEM ADMIN CREDENTIALS
==================================================================
Created on: $(date)
Username:   ${username}
Password:   ${password}
Sudo Group: ${SUDO_GROUP}

⚠️  IMPORTANT:
1. Save this password in a safe place.
2. Log in using this user for future server management:
   ssh ${username}@<vps-ip>
3. Running commands: use 'sudo <command>'
==================================================================
EOF
chmod 600 "$CREDENTIALS_FILE"

echo ""
echo -e "${GREEN}==================================================================${NC}"
log_success "Admin user created successfully!"
echo -e "${GREEN}==================================================================${NC}"
echo -e "  Username:  ${BLUE}${username}${NC}"
echo -e "  Password:  ${YELLOW}${password}${NC}"
echo -e "  Sudo:      Yes"
echo -e "=================================================================="
echo -e "Credentials saved to: ${GREEN}$PWD/$CREDENTIALS_FILE${NC}"
echo -e "=================================================================="
echo ""
