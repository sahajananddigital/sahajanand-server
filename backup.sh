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

# Configuration and Defaults
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
CLIENTS_DIR="$PROJECT_ROOT/clients"
BACKUP_DIR="${BACKUP_DIR:-/tmp/sahajanand-backups}"

# Options and Defaults
CLIENT_FILTER=""
BACKUP_TYPE="all"
LOCAL_ONLY=false
RCLONE_REMOTE=""
IS_CONTAINER=false

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

# Help function
show_help() {
    echo "Usage: ./backup.sh [options] [rclone-remote:path]"
    echo ""
    echo "Options:"
    echo "  -c, --client NAME      Only backup the specified client"
    echo "  -t, --type TYPE        Backup type: 'all' (default), 'database', or 'files'"
    echo "  -l, --local-only       Skip uploading to rclone remote"
    echo "  -h, --help             Display this help message"
    echo ""
    echo "If rclone-remote:path is omitted, it will read RCLONE_REMOTE_PATH from .env"
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--client)
            CLIENT_FILTER="$2"
            shift 2
            ;;
        -t|--type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        -l|--local-only)
            LOCAL_ONLY=true
            shift 1
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            RCLONE_REMOTE="$1"
            shift 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for rclone (only if uploading is required)
    if [ -n "$RCLONE_REMOTE" ] && [ "$LOCAL_ONLY" = false ]; then
        if ! command -v rclone &> /dev/null; then
            log_error "rclone is not installed. Please install it first or run with --local-only."
            exit 1
        fi
        
        # Check rclone remote
        local rclone_opts=()
        if [ -n "${RCLONE_CONFIG_PATH:-}" ]; then
            rclone_opts+=("--config" "$RCLONE_CONFIG_PATH")
        fi
        
        local remote_name=$(echo "$RCLONE_REMOTE" | cut -d: -f1)
        # Verify if remote is recognized
        if ! rclone "${rclone_opts[@]:+${rclone_opts[@]}}" listremotes | grep -q "^${remote_name}:"; then
            log_warn "rclone remote '${remote_name}' not listed in configured remotes."
            log_warn "It might be configured dynamically via env variables. Proceeding..."
        fi
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
    
    log_info "Prerequisites check passed."
}

# Load environment variables from .env
load_env() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        log_info "Loading environment from .env file..."
        # Export env vars, ignoring comments and empty lines
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
                continue
            fi
            # Use eval or direct export to support value quotes
            if [[ "$line" =~ ^[[:alpha:]_][[:alnum:]_]*= ]]; then
                export "$line"
            fi
        done < "$PROJECT_ROOT/.env"
    fi

    # Determine if running in Docker
    if [ -f /.dockerenv ]; then
        IS_CONTAINER=true
    else
        IS_CONTAINER=false
    fi

    # Dynamically resolve relative/container paths if running on host
    if [ "$IS_CONTAINER" = false ]; then
        if [ -n "${RCLONE_CONFIG_GDRIVE_SERVICE_ACCOUNT_FILE:-}" ] && [[ "$RCLONE_CONFIG_GDRIVE_SERVICE_ACCOUNT_FILE" == "/var/www/project/"* ]]; then
            export RCLONE_CONFIG_GDRIVE_SERVICE_ACCOUNT_FILE="${PROJECT_ROOT}/${RCLONE_CONFIG_GDRIVE_SERVICE_ACCOUNT_FILE#/var/www/project/}"
        fi
        if [ -n "${RCLONE_CONFIG_PATH:-}" ] && [[ "$RCLONE_CONFIG_PATH" == "/var/www/project/"* ]]; then
            export RCLONE_CONFIG_PATH="${PROJECT_ROOT}/${RCLONE_CONFIG_PATH#/var/www/project/}"
        fi
    fi

    MYSQL_ROOT_PASS="${MYSQL_ROOT_PASSWORD:-rootpassword}"

    # Use remote from env if not specified via argument
    if [ -z "$RCLONE_REMOTE" ] && [ "$LOCAL_ONLY" = false ]; then
        RCLONE_REMOTE="${RCLONE_REMOTE_PATH:-}"
    fi
}

# Get list of clients
get_clients() {
    local clients=()
    if [ -n "$CLIENT_FILTER" ]; then
        if [ -d "$CLIENTS_DIR/$CLIENT_FILTER" ] && [ -f "$CLIENTS_DIR/$CLIENT_FILTER/docker-compose.yml" ]; then
            clients+=("$CLIENT_FILTER")
        else
            log_error "Client '$CLIENT_FILTER' not found in $CLIENTS_DIR or lacks docker-compose.yml"
            exit 1
        fi
    else
        for client_dir in "$CLIENTS_DIR"/*/; do
            if [ -d "$client_dir" ] && [ -f "$client_dir/docker-compose.yml" ]; then
                local client_name=$(basename "$client_dir")
                clients+=("$client_name")
            fi
        done
    fi
    echo "${clients[@]}"
}

# Backup database (MySQL or SQLite) for a client
backup_database() {
    local client_name="$1"
    local base_backup_path="$2"
    
    # Check if there are SQLite databases in the client folder
    local client_db_dir="$CLIENTS_DIR/$client_name/database"
    if [ -d "$client_db_dir" ] && ls "$client_db_dir"/*.db &>/dev/null; then
        log_info "Backing up SQLite database(s) for client: $client_name"
        local tar_file="${base_backup_path}.tar"
        tar -cf "$tar_file" -C "$client_db_dir" .
        echo "$tar_file"
        return 0
    fi
    
    # Fallback to MySQL if SQLite is not used and mysql container is running
    if [ "${SKIP_DB_BACKUP:-true}" = false ]; then
        log_info "Backing up MySQL database for client: $client_name"
        local db_name="${client_name}_db"
        # Check if database exists
        if ! docker exec mysql mysql -u root -p"${MYSQL_ROOT_PASS}" -e "USE \`${db_name}\`;" 2>/dev/null; then
            log_warn "Database $db_name does not exist. Skipping..."
            return 0
        fi
        
        local sql_file="${base_backup_path}.sql"
        # Dump database
        if docker exec mysql mysqldump -u root -p"${MYSQL_ROOT_PASS}" \
            --single-transaction \
            --routines \
            --triggers \
            --add-drop-database \
            --databases "${db_name}" > "$sql_file"; then
            echo "$sql_file"
            return 0
        fi
    fi
    
    return 0
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
    
    if [ -z "$RCLONE_REMOTE" ] || [ "$LOCAL_ONLY" = true ]; then
        log_warn "No rclone remote specified or local-only mode. Skipping upload."
        return 0
    fi
    
    local remote_dir="${RCLONE_REMOTE}/${client_name}/${backup_type}"
    local rclone_opts=()
    if [ -n "${RCLONE_CONFIG_PATH:-}" ]; then
        rclone_opts+=("--config" "$RCLONE_CONFIG_PATH")
    fi
    
    log_info "Uploading to rclone: ${remote_dir}/$(basename "$file")"
    
    # We use 'rclone copy' to copy the file into the destination directory.
    # We use POSIX-safe array expansion for older bash versions under 'set -u'.
    if rclone ${rclone_opts[@]+"${rclone_opts[@]}"} copy "$file" "${remote_dir}" --progress; then
        log_info "Uploaded successfully: ${remote_dir}/$(basename "$file")"
        return 0
    else
        log_error "Failed to upload: ${remote_dir}/$(basename "$file")"
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
    log_info "Backing up client: $client_name (Type: $BACKUP_TYPE)"
    log_info "=========================================="
    
    # Backup database (MySQL or SQLite)
    if [ "$BACKUP_TYPE" = "all" ] || [ "$BACKUP_TYPE" = "database" ]; then
        local db_backup_base="${client_backup_dir}/${client_name}_db_${timestamp}"
        # backup_database echoes the actual file created (.sql or .tar)
        local db_backup=$(backup_database "$client_name" "$db_backup_base" 2>/dev/null || true)
        
        # Strip trailing carriage returns or control codes from command output
        db_backup=$(echo "$db_backup" | tr -d '\r\n')
        
        if [ -n "$db_backup" ] && [ -f "$db_backup" ] && [ -s "$db_backup" ]; then
            local compressed_db=$(compress_with_zstd "$db_backup")
            if [ -n "$compressed_db" ]; then
                upload_to_rclone "$compressed_db" "$client_name" "database"
            fi
        fi
    fi
    
    # Backup client files
    if [ "$BACKUP_TYPE" = "all" ] || [ "$BACKUP_TYPE" = "files" ]; then
        local files_backup="${client_backup_dir}/${client_name}_files_${timestamp}.tar"
        if backup_client_files "$client_name" "$files_backup"; then
            if [ -f "$files_backup" ]; then
                local compressed_files=$(compress_with_zstd "$files_backup")
                if [ -n "$compressed_files" ]; then
                    upload_to_rclone "$compressed_files" "$client_name" "files"
                fi
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
        find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null || true
    fi
}

# Main execution
main() {
    log_info "=========================================="
    log_info "Sahajanand Server Backup Script"
    log_info "=========================================="
    log_info "Started at: $(date)"
    
    # Load env variables from .env
    load_env
    
    # Check prerequisites
    check_prerequisites
    
    # Get list of clients
    local clients=($(get_clients))
    
    if [ ${#clients[@]} -eq 0 ]; then
        log_warn "No clients found to back up."
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
    
    if [ -n "$RCLONE_REMOTE" ] && [ "$LOCAL_ONLY" = false ]; then
        log_info "Backups uploaded to rclone: $RCLONE_REMOTE"
    else
        log_info "Local backups stored in: $BACKUP_DIR"
    fi
    log_info "=========================================="
}

# Run main function
main "$@"

