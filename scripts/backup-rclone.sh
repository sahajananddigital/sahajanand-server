#!/usr/bin/env bash
# ==============================================================================
# Script: backup-rclone.sh
# Purpose: Automated backup of MariaDB databases, Invoice Ninja storage,
#          application data, and server configurations to Rclone remote.
# Target: 4GB RAM Hetzner ARM64 Docker Infrastructure / macOS Development
# ==============================================================================

set -euo pipefail

# ANSI Color Codes
CLR_RESET="\033[0m"
CLR_RED="\033[0;31m"
CLR_GREEN="\033[0;32m"
CLR_YELLOW="\033[1;33m"
CLR_CYAN="\033[0;36m"
CLR_BOLD="\033[1m"

log_info() {
    echo -e "${CLR_CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${CLR_RESET} $*"
}

log_success() {
    echo -e "${CLR_GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${CLR_RESET} $*"
}

log_warn() {
    echo -e "${CLR_YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${CLR_RESET} $*"
}

log_error() {
    echo -e "${CLR_RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${CLR_RESET} $*" >&2
}

# Resolve script & repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default Configuration
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive:sahajanandserver/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
MARIADB_CONTAINER="${MARIADB_CONTAINER:-shared_mariadb}"
INVOICENINJA_CONTAINER="${INVOICENINJA_CONTAINER:-invoiceninja_app}"
SKIP_OPENWA=false
DRY_RUN=false
DB_ONLY=false
KEEP_LOCAL=false
CUSTOM_LOCAL_DIR=""

show_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --remote <remote>     Rclone remote path (default: ${RCLONE_REMOTE})
  --retention <days>    Prune remote backups older than <days> (default: ${RETENTION_DAYS})
  --db-only             Backup databases only (skip files and configs)
  --skip-openwa         Skip backing up OpenWA session data (speeds up backup)
  --keep-local          Keep a local copy of the backup archive in ./backups/
  --local-dir <dir>     Save local backups to specified directory
  --dry-run             Generate local backup bundle but skip rclone upload & pruning
  -h, --help            Show this help message

Environment Variables:
  RCLONE_REMOTE         Destination rclone remote (e.g. gdrive:sahajanandserver/backups)
  RETENTION_DAYS        Days to retain remote backups (default: 7)
  MARIADB_ROOT_PASSWORD MariaDB root password (defaults to core-infra/.env value)

Example:
  $(basename "$0")
  $(basename "$0") --db-only
  $(basename "$0") --keep-local --retention 14
EOF
}

# Parse Command Line Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --remote)
            RCLONE_REMOTE="$2"
            shift 2
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --db-only)
            DB_ONLY=true
            shift
            ;;
        --skip-openwa)
            SKIP_OPENWA=true
            shift
            ;;
        --keep-local)
            KEEP_LOCAL=true
            shift
            ;;
        --local-dir)
            KEEP_LOCAL=true
            CUSTOM_LOCAL_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            KEEP_LOCAL=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Prerequisite Checks
log_info "=================================================="
log_info " Starting Sahajanand Server Automated Backup"
log_info "=================================================="

if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is required but not installed."
    exit 1
fi

if [ "${DRY_RUN}" = false ]; then
    if ! command -v rclone >/dev/null 2>&1; then
        log_error "Rclone is required but not installed."
        exit 1
    fi
fi

# Load MariaDB Root Password
if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    CORE_ENV="${REPO_ROOT}/core-infra/.env"
    if [ -f "${CORE_ENV}" ]; then
        MARIADB_ROOT_PASSWORD="$(grep -E '^MARIADB_ROOT_PASSWORD=' "${CORE_ENV}" | cut -d '=' -f2- | tr -d '"'"'" || true)"
    fi
fi

if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    log_error "MARIADB_ROOT_PASSWORD could not be found in environment or ${REPO_ROOT}/core-infra/.env"
    exit 1
fi

# Verify MariaDB container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${MARIADB_CONTAINER}$"; then
    log_error "MariaDB container '${MARIADB_CONTAINER}' is not running."
    exit 1
fi

# Setup Working Directories
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
TEMP_BACKUP_DIR="$(mktemp -d -t sahajanand_backup_XXXXXX)"
STAGING_DIR="${TEMP_BACKUP_DIR}/sahajanand_backup_${TIMESTAMP}"
mkdir -p "${STAGING_DIR}/database" "${STAGING_DIR}/storage" "${STAGING_DIR}/configs"

cleanup() {
    if [ -d "${TEMP_BACKUP_DIR}" ]; then
        rm -rf "${TEMP_BACKUP_DIR}"
    fi
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# 1. Database Dumps
# ------------------------------------------------------------------------------
log_info "Dumping MariaDB databases..."

# Invoice Ninja dedicated dump
IN_DB_FILE="${STAGING_DIR}/database/invoiceninja_${TIMESTAMP}.sql.gz"
log_info "  -> Dumping 'invoiceninja' database..."
docker exec "${MARIADB_CONTAINER}" mariadb-dump \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    --single-transaction --quick invoiceninja | gzip -9 > "${IN_DB_FILE}"

if [ ! -s "${IN_DB_FILE}" ]; then
    log_error "Failed to dump 'invoiceninja' database (output file is empty)."
    exit 1
fi
IN_DB_SIZE="$(du -h "${IN_DB_FILE}" | cut -f1)"
log_success "  [✓] invoiceninja.sql.gz (${IN_DB_SIZE})"

# FreeScout dedicated dump (if exists)
if docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW DATABASES LIKE 'freescout';" | grep -q "freescout"; then
    FS_DB_FILE="${STAGING_DIR}/database/freescout_${TIMESTAMP}.sql.gz"
    log_info "  -> Dumping 'freescout' database..."
    docker exec "${MARIADB_CONTAINER}" mariadb-dump \
        -u root -p"${MARIADB_ROOT_PASSWORD}" \
        --single-transaction --quick freescout | gzip -9 > "${FS_DB_FILE}"
    if [ -s "${FS_DB_FILE}" ]; then
        log_success "  [✓] freescout.sql.gz ($(du -h "${FS_DB_FILE}" | cut -f1))"
    fi
fi

# Full instance dump (all databases)
ALL_DB_FILE="${STAGING_DIR}/database/all_databases_${TIMESTAMP}.sql.gz"
log_info "  -> Dumping all databases (--all-databases)..."
docker exec "${MARIADB_CONTAINER}" mariadb-dump \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    --single-transaction --quick --all-databases | gzip -9 > "${ALL_DB_FILE}"

if [ ! -s "${ALL_DB_FILE}" ]; then
    log_error "Failed to dump all databases (output file is empty)."
    exit 1
fi
ALL_DB_SIZE="$(du -h "${ALL_DB_FILE}" | cut -f1)"
log_success "  [✓] all_databases.sql.gz (${ALL_DB_SIZE})"

# ------------------------------------------------------------------------------
# 2. Application Files & Persistent Storage
# ------------------------------------------------------------------------------
if [ "${DB_ONLY}" = false ]; then
    # Invoice Ninja Storage
    log_info "Archiving Invoice Ninja storage..."
    if docker ps --format '{{.Names}}' | grep -q "^${INVOICENINJA_CONTAINER}$"; then
        IN_STORAGE_FILE="${STAGING_DIR}/storage/invoiceninja_storage_${TIMESTAMP}.tar.gz"
        docker exec "${INVOICENINJA_CONTAINER}" tar -czf - \
            -C /var/www/html/storage \
            --exclude='framework/cache/*' \
            --exclude='framework/sessions/*' \
            --exclude='framework/views/*' \
            --exclude='logs/*' \
            . > "${IN_STORAGE_FILE}"
        
        IN_STORAGE_SIZE="$(du -h "${IN_STORAGE_FILE}" | cut -f1)"
        log_success "  [✓] invoiceninja_storage.tar.gz (${IN_STORAGE_SIZE})"
    else
        log_warn "Invoice Ninja app container '${INVOICENINJA_CONTAINER}' not running; skipping storage archive."
    fi

    # FreeScout Data (if running)
    if docker ps --format '{{.Names}}' | grep -q "^freescout$"; then
        FS_STORAGE_FILE="${STAGING_DIR}/storage/freescout_data_${TIMESTAMP}.tar.gz"
        log_info "Archiving FreeScout persistent data..."
        docker run --rm -v freescout_freescout_data:/data:ro alpine tar -czf - -C /data . > "${FS_STORAGE_FILE}" 2>/dev/null || true
        if [ -s "${FS_STORAGE_FILE}" ]; then
            log_success "  [✓] freescout_data.tar.gz ($(du -h "${FS_STORAGE_FILE}" | cut -f1))"
        else
            rm -f "${FS_STORAGE_FILE}"
        fi
    fi

    # OpenWA Data (if running and not skipped)
    if [ "${SKIP_OPENWA}" = false ] && docker ps --format '{{.Names}}' | grep -q "^openwa$"; then
        OPENWA_FILE="${STAGING_DIR}/storage/openwa_data_${TIMESTAMP}.tar.gz"
        log_info "Archiving OpenWA data..."
        docker run --rm -v openwa_openwa_data:/data:ro alpine tar -czf - -C /data . > "${OPENWA_FILE}" 2>/dev/null || true
        if [ -s "${OPENWA_FILE}" ]; then
            log_success "  [✓] openwa_data.tar.gz ($(du -h "${OPENWA_FILE}" | cut -f1))"
        else
            rm -f "${OPENWA_FILE}"
        fi
    fi

    # Uptime Kuma Data (if running)
    if docker ps --format '{{.Names}}' | grep -q "^uptime_kuma$"; then
        KUMA_FILE="${STAGING_DIR}/storage/uptime_kuma_data_${TIMESTAMP}.tar.gz"
        log_info "Archiving Uptime Kuma data..."
        docker run --rm -v uptime-kuma_uptime_kuma_data:/data:ro alpine tar -czf - -C /data . > "${KUMA_FILE}" 2>/dev/null || true
        if [ -s "${KUMA_FILE}" ]; then
            log_success "  [✓] uptime_kuma_data.tar.gz ($(du -h "${KUMA_FILE}" | cut -f1))"
        else
            rm -f "${KUMA_FILE}"
        fi
    fi

    # Gitea Data (if running)
    if docker ps --format '{{.Names}}' | grep -q "^gitea$"; then
        GITEA_FILE="${STAGING_DIR}/storage/gitea_data_${TIMESTAMP}.tar.gz"
        log_info "Archiving Gitea data..."
        docker run --rm -v gitea_gitea_data:/data:ro alpine tar -czf - -C /data . > "${GITEA_FILE}" 2>/dev/null || true
        if [ -s "${GITEA_FILE}" ]; then
            log_success "  [✓] gitea_data.tar.gz ($(du -h "${GITEA_FILE}" | cut -f1))"
        else
            rm -f "${GITEA_FILE}"
        fi
    fi

    # Caddy TLS Certificates & Configuration
    if docker ps --format '{{.Names}}' | grep -q "^caddy$"; then
        CADDY_FILE="${STAGING_DIR}/storage/caddy_tls_data_${TIMESTAMP}.tar.gz"
        log_info "Archiving Caddy TLS certificates & data..."
        docker run --rm -v core-infra_caddy_data:/data:ro alpine tar -czf - -C /data . > "${CADDY_FILE}" 2>/dev/null || true
        if [ -s "${CADDY_FILE}" ]; then
            log_success "  [✓] caddy_tls_data.tar.gz ($(du -h "${CADDY_FILE}" | cut -f1))"
        else
            rm -f "${CADDY_FILE}"
        fi
    fi

    # --------------------------------------------------------------------------
    # 3. Server Configuration & Environment Files
    # --------------------------------------------------------------------------
    log_info "Archiving server configurations & .env files..."
    CONFIGS_FILE="${STAGING_DIR}/configs/server_configs_${TIMESTAMP}.tar.gz"
    tar -czf "${CONFIGS_FILE}" \
        -C "${REPO_ROOT}" \
        --exclude='*.git*' \
        --exclude='*.db' \
        --exclude='*.pdf' \
        --exclude='backups*' \
        core-infra \
        apps \
        scripts \
        README.md 2>/dev/null || true

    CONFIGS_SIZE="$(du -h "${CONFIGS_FILE}" | cut -f1)"
    log_success "  [✓] server_configs.tar.gz (${CONFIGS_SIZE})"
fi

# ------------------------------------------------------------------------------
# 4. Generate Manifest & Package Backup Bundle
# ------------------------------------------------------------------------------
log_info "Generating backup manifest..."
cat <<EOF > "${STAGING_DIR}/manifest.txt"
==================================================
 Sahajanand Server Backup Manifest
==================================================
Backup Date       : $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Local Timestamp   : ${TIMESTAMP}
Host              : $(hostname)
Repository Root   : ${REPO_ROOT}
DB-Only Mode      : ${DB_ONLY}

Included Artifacts:
$(find "${STAGING_DIR}" -type f -not -name "manifest.txt" -exec ls -lh {} + | awk '{print "  " $9 " (" $5 ")"}')

Running Containers at Backup Time:
$(docker ps --format "  - {{.Names}} ({{.Image}}) - {{.Status}}")
==================================================
EOF

BUNDLE_NAME="sahajanand-backup_${TIMESTAMP}.tar.gz"
BUNDLE_PATH="${TEMP_BACKUP_DIR}/${BUNDLE_NAME}"

log_info "Compressing final bundle: ${BUNDLE_NAME}..."
tar -czf "${BUNDLE_PATH}" -C "${TEMP_BACKUP_DIR}" "sahajanand_backup_${TIMESTAMP}"
BUNDLE_SIZE="$(du -h "${BUNDLE_PATH}" | cut -f1)"
log_success "Backup bundle created successfully: ${BUNDLE_NAME} (${BUNDLE_SIZE})"

# ------------------------------------------------------------------------------
# 5. Local Copy Retention (if requested)
# ------------------------------------------------------------------------------
if [ "${KEEP_LOCAL}" = true ]; then
    LOCAL_DEST_DIR="${CUSTOM_LOCAL_DIR:-${REPO_ROOT}/backups}"
    mkdir -p "${LOCAL_DEST_DIR}"
    cp "${BUNDLE_PATH}" "${LOCAL_DEST_DIR}/${BUNDLE_NAME}"
    log_success "Local copy saved to: ${LOCAL_DEST_DIR}/${BUNDLE_NAME}"
fi

# ------------------------------------------------------------------------------
# 6. Upload to Rclone Remote
# ------------------------------------------------------------------------------
if [ "${DRY_RUN}" = true ]; then
    log_warn "DRY-RUN mode enabled. Skipping rclone upload and retention pruning."
else
    log_info "Uploading backup bundle to rclone remote: ${RCLONE_REMOTE}..."
    rclone copy "${BUNDLE_PATH}" "${RCLONE_REMOTE}/" --progress --stats-one-line
    log_success "Upload completed successfully to ${RCLONE_REMOTE}/${BUNDLE_NAME}"

    # --------------------------------------------------------------------------
    # 7. Retention Management / Pruning
    # --------------------------------------------------------------------------
    if [ "${RETENTION_DAYS}" -gt 0 ]; then
        log_info "Pruning remote backups older than ${RETENTION_DAYS} days from ${RCLONE_REMOTE}..."
        # Delete backups older than RETENTION_DAYS
        rclone delete --min-age "${RETENTION_DAYS}d" "${RCLONE_REMOTE}/" 2>/dev/null || true
        log_success "Remote retention policy applied (<= ${RETENTION_DAYS} days kept)."
    fi
fi

log_info "=================================================="
log_success " Backup completed successfully at $(date '+%Y-%m-%d %H:%M:%S')!"
log_info "=================================================="
