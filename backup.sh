#!/bin/bash

# Backup script for Sahajanand Server Infrastructure
# Backs up MySQL databases and client data separately for each client
# Compresses with zstd and uploads to rclone remote
#
# Usage: ./backup.sh [rclone-remote:path]
# Example: ./backup.sh myremote:backups/sahajanand-server
#
# Requirements:
# - rclone installed and configured
# - zstd installed
# - docker and docker-compose available
# - MySQL container running (for database backups)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
CLIENTS_DIR="$PROJECT_ROOT/clients"
BACKUP_DIR="${BACKUP_DIR:-/tmp/sahajanand-backups}"
RCLONE_REMOTE="${1:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for rclone
    if ! command -v rclone &> /dev/null; then
        log_error "rclone is not installed. Please install it first."
        exit 1
    fi
    
    # Check for zstd
    if ! command -v zstd &> /dev/null; then
        log_error "zstd is not installed. Please install it first."
        log_info "Install with: brew install zstd (macOS) or apt-get install zstd (Linux)"
        exit 1
    fi
    
    # Check for docker
    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed."
        exit 1
    fi
    
    # Check if MySQL container is running
    if ! docker ps | grep -q "mysql"; then
        log_warn "MySQL container is not running. Database backups will be skipped."
        SKIP_DB_BACKUP=true
    else
        SKIP_DB_BACKUP=false
    fi
    
    # Check rclone remote if provided
    if [ -n "$RCLONE_REMOTE" ]; then
        REMOTE_NAME=$(echo "$RCLONE_REMOTE" | cut -d: -f1)
        if ! rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
            log_error "rclone remote '${REMOTE_NAME}' not found."
            log_info "Configure it with: rclone config"
            exit 1
        fi
    fi
    
    log_info "Prerequisites check passed."
}

# Load MySQL root password from .env
load_mysql_config() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        export $(grep -v '^#' "$PROJECT_ROOT/.env" | grep MYSQL_ROOT_PASSWORD | xargs)
    fi
    MYSQL_ROOT_PASS="${MYSQL_ROOT_PASSWORD:-rootpassword}"
}

# Get list of clients
get_clients() {
    local clients=()
    for client_dir in "$CLIENTS_DIR"/*/; do
        if [ -d "$client_dir" ] && [ -f "$client_dir/docker-compose.yml" ]; then
            local client_name=$(basename "$client_dir")
            clients+=("$client_name")
        fi
    done
    echo "${clients[@]}"
}

# Backup MySQL database for a client
backup_mysql_database() {
    local client_name="$1"
    local backup_file="$2"
    local db_name="${client_name}_db"
    
    log_info "Backing up MySQL database: $db_name"
    
    if [ "$SKIP_DB_BACKUP" = true ]; then
        log_warn "Skipping MySQL backup (container not running)"
        return 0
    fi
    
    # Check if database exists
    if ! docker exec mysql mysql -u root -p"${MYSQL_ROOT_PASS}" -e "USE \`${db_name}\`;" 2>/dev/null; then
        log_warn "Database $db_name does not exist. Skipping..."
        return 0
    fi
    
    # Dump database
    if docker exec mysql mysqldump -u root -p"${MYSQL_ROOT_PASS}" \
        --single-transaction \
        --routines \
        --triggers \
        --add-drop-database \
        --databases "${db_name}" > "$backup_file"; then
        log_info "MySQL backup created: $backup_file"
        return 0
    else
        log_error "Failed to backup MySQL database: $db_name"
        return 1
    fi
}

# Backup client files
backup_client_files() {
    local client_name="$1"
    local backup_file="$2"
    local client_dir="$CLIENTS_DIR/$client_name"
    
    log_info "Backing up client files: $client_name"
    
    # Exclude unnecessary files from backup (create tar, not compressed yet)
    tar --exclude='*.log' \
        --exclude='*.pid' \
        --exclude='__pycache__' \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='.env' \
        -cf "$backup_file" -C "$CLIENTS_DIR" "$client_name"
    
    if [ $? -eq 0 ]; then
        log_info "Client files backup created: $backup_file"
        return 0
    else
        log_error "Failed to backup client files: $client_name"
        return 1
    fi
}

# Compress file with zstd
compress_with_zstd() {
    local input_file="$1"
    local output_file="${input_file}.zst"
    
    log_info "Compressing with zstd: $(basename "$input_file")"
    
    if zstd -f -10 "$input_file" -o "$output_file"; then
        log_info "Compressed: $output_file"
        rm -f "$input_file"  # Remove uncompressed file
        echo "$output_file"
        return 0
    else
        log_error "Failed to compress: $input_file"
        return 1
    fi
}

# Upload to rclone
upload_to_rclone() {
    local file="$1"
    local client_name="$2"
    local backup_type="$3"  # "database" or "files"
    
    if [ -z "$RCLONE_REMOTE" ]; then
        log_warn "No rclone remote specified. Skipping upload."
        return 0
    fi
    
    local remote_path="${RCLONE_REMOTE}/${client_name}/${backup_type}/$(basename "$file")"
    
    log_info "Uploading to rclone: $remote_path"
    
    if rclone copy "$file" "${remote_path}" --progress; then
        log_info "Uploaded successfully: $remote_path"
        return 0
    else
        log_error "Failed to upload: $remote_path"
        return 1
    fi
}

# Main backup function for a client
backup_client() {
    local client_name="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local client_backup_dir="$BACKUP_DIR/$client_name"
    
    mkdir -p "$client_backup_dir"
    
    log_info "=========================================="
    log_info "Backing up client: $client_name"
    log_info "=========================================="
    
    # Backup MySQL database
    local db_backup="${client_backup_dir}/${client_name}_db_${timestamp}.sql"
    if backup_mysql_database "$client_name" "$db_backup"; then
        if [ -f "$db_backup" ] && [ -s "$db_backup" ]; then
            local compressed_db=$(compress_with_zstd "$db_backup")
            if [ -n "$compressed_db" ]; then
                upload_to_rclone "$compressed_db" "$client_name" "database"
            fi
        fi
    fi
    
    # Backup client files
    local files_backup="${client_backup_dir}/${client_name}_files_${timestamp}.tar"
    if backup_client_files "$client_name" "$files_backup"; then
        if [ -f "$files_backup" ]; then
            local compressed_files=$(compress_with_zstd "$files_backup")
            if [ -n "$compressed_files" ]; then
                upload_to_rclone "$compressed_files" "$client_name" "files"
            fi
        fi
    fi
    
    log_info "Backup completed for: $client_name"
}

# Cleanup old local backups (optional)
cleanup_local_backups() {
    if [ -d "$BACKUP_DIR" ]; then
        log_info "Cleaning up local backup directory..."
        # Keep backups for 7 days locally
        find "$BACKUP_DIR" -type f -name "*.zst" -mtime +7 -delete
        find "$BACKUP_DIR" -type d -empty -delete
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Sahajanand Server Backup Script"
    log_info "=========================================="
    log_info "Started at: $(date)"
    
    # Check prerequisites
    check_prerequisites
    
    # Load MySQL configuration
    load_mysql_config
    
    # Get list of clients
    local clients=($(get_clients))
    
    if [ ${#clients[@]} -eq 0 ]; then
        log_warn "No clients found in $CLIENTS_DIR"
        exit 0
    fi
    
    log_info "Found ${#clients[@]} client(s): ${clients[*]}"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Backup each client
    for client in "${clients[@]}"; do
        backup_client "$client"
    done
    
    # Cleanup old local backups
    cleanup_local_backups
    
    log_info "=========================================="
    log_info "All backups completed!"
    log_info "Finished at: $(date)"
    
    if [ -n "$RCLONE_REMOTE" ]; then
        log_info "Backups uploaded to: $RCLONE_REMOTE"
    else
        log_info "Local backups stored in: $BACKUP_DIR"
    fi
    log_info "=========================================="
}

# Run main function
main "$@"

