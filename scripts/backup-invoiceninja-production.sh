#!/usr/bin/env bash
# ==============================================================================
# Script: backup-invoiceninja-production.sh
# Purpose: Create a standalone, production-ready Invoice Ninja backup bundle
#          containing the database, persistent storage, APP_KEY, configs,
#          and an automated import script for production migration.
# ==============================================================================

set -euo pipefail

# ANSI Colors
CLR_RESET="\033[0m"
CLR_RED="\033[0;31m"
CLR_GREEN="\033[0;32m"
CLR_YELLOW="\033[1;33m"
CLR_CYAN="\033[0;36m"
CLR_BOLD="\033[1m"

log_info() { echo -e "${CLR_CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${CLR_RESET} $*"; }
log_success() { echo -e "${CLR_GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${CLR_RESET} $*"; }
log_warn() { echo -e "${CLR_YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${CLR_RESET} $*"; }
log_error() { echo -e "${CLR_RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${CLR_RESET} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive:sahajanandserver/backups/invoiceninja}"
MARIADB_CONTAINER="${MARIADB_CONTAINER:-shared_mariadb}"
INVOICENINJA_CONTAINER="${INVOICENINJA_CONTAINER:-invoiceninja_app}"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
OUTPUT_DIR="${REPO_ROOT}/backups"
DRY_RUN=false

show_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --remote <remote>   Rclone remote path (default: ${RCLONE_REMOTE})
  --out <dir>         Local output directory (default: ./backups)
  --dry-run           Create local package only (skip uploading to Rclone)
  -h, --help          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --remote) RCLONE_REMOTE="$2"; shift 2 ;;
        --out) OUTPUT_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

log_info "=================================================="
log_info " Packaging Standalone Invoice Ninja Backup Bundle "
log_info "=================================================="

# Check requirements
command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed."; exit 1; }
if [ "${DRY_RUN}" = false ]; then
    command -v rclone >/dev/null 2>&1 || { log_error "Rclone is required but not installed."; exit 1; }
fi

# Load MariaDB Root Password
if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    CORE_ENV="${REPO_ROOT}/core-infra/.env"
    if [ -f "${CORE_ENV}" ]; then
        MARIADB_ROOT_PASSWORD="$(grep -E '^MARIADB_ROOT_PASSWORD=' "${CORE_ENV}" | cut -d '=' -f2- | tr -d '"'"'" || true)"
    fi
fi
[ -n "${MARIADB_ROOT_PASSWORD:-}" ] || { log_error "MARIADB_ROOT_PASSWORD not found."; exit 1; }

# Verify containers are running
docker ps --format '{{.Names}}' | grep -q "^${MARIADB_CONTAINER}$" || { log_error "${MARIADB_CONTAINER} is not running."; exit 1; }
docker ps --format '{{.Names}}' | grep -q "^${INVOICENINJA_CONTAINER}$" || { log_error "${INVOICENINJA_CONTAINER} is not running."; exit 1; }

# Prepare staging directory
TEMP_DIR="$(mktemp -d -t in_backup_XXXXXX)"
STAGING="${TEMP_DIR}/invoiceninja-production-backup_${TIMESTAMP}"
mkdir -p "${STAGING}/database" "${STAGING}/storage" "${STAGING}/config" "${OUTPUT_DIR}"

cleanup() { [ -d "${TEMP_DIR}" ] && rm -rf "${TEMP_DIR}"; }
trap cleanup EXIT

# 1. Dump Database
log_info "1. Exporting MariaDB 'invoiceninja' database..."
SQL_FILE="${STAGING}/database/invoiceninja.sql"
docker exec "${MARIADB_CONTAINER}" mariadb-dump \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    --single-transaction \
    --quick \
    --add-drop-table \
    --routines \
    --triggers \
    invoiceninja > "${SQL_FILE}"

gzip -9 -c "${SQL_FILE}" > "${SQL_FILE}.gz"
log_success "  [✓] Database exported: $(du -h "${SQL_FILE}.gz" | cut -f1) (compressed) / $(du -h "${SQL_FILE}" | cut -f1) (raw)"

# 2. Archive Storage
log_info "2. Archiving persistent storage (/var/www/html/storage)..."
STORAGE_TAR="${STAGING}/storage/storage.tar.gz"
docker exec "${INVOICENINJA_CONTAINER}" tar -czf - \
    -C /var/www/html/storage \
    --exclude='framework/cache/*' \
    --exclude='framework/sessions/*' \
    --exclude='framework/views/*' \
    --exclude='logs/*' \
    . > "${STORAGE_TAR}"
log_success "  [✓] Storage archived: $(du -h "${STORAGE_TAR}" | cut -f1)"

# 3. Export Configurations & Template for Production
log_info "3. Exporting configurations & environment..."
cp "${REPO_ROOT}/apps/invoiceninja/docker-compose.yml" "${STAGING}/config/docker-compose.yml"
cp "${REPO_ROOT}/apps/invoiceninja/in-vhost.conf" "${STAGING}/config/in-vhost.conf"
[ -f "${REPO_ROOT}/apps/invoiceninja/.env" ] && cp "${REPO_ROOT}/apps/invoiceninja/.env" "${STAGING}/config/local.env"

# Extract APP_KEY from current .env
APP_KEY="$(grep -E '^APP_KEY=' "${REPO_ROOT}/apps/invoiceninja/.env" | cut -d '=' -f2- || true)"

# Create a clean production template with the EXACT SAME APP_KEY
cat <<EOF > "${STAGING}/config/production.env.example"
# ==============================================================================
# Invoice Ninja Production Environment Configuration
# NOTE: APP_KEY MUST match the backup's APP_KEY to decrypt existing tokens/data!
# ==============================================================================

APP_URL=https://erp.app.sahajananddigital.in
APP_KEY=${APP_KEY}
APP_ENV=production
APP_DEBUG=false
REQUIRE_HTTPS=true
PHANTOMJS_PDF_GENERATION=false
PDF_GENERATOR=hosted_ninja
TRUSTED_PROXIES=*

DB_CONNECTION=mysql
DB_HOST=shared_mariadb
DB_PORT=3306
DB_DATABASE=invoiceninja
DB_USERNAME=invoiceninja
DB_PASSWORD=NinjaSecretPass123!

CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
REDIS_HOST=shared_redis
REDIS_PORT=6379
REDIS_PASSWORD=null

IN_USER_EMAIL=admin@sahajananddigital.in
IN_PASSWORD=AdminNinjaPass123!
EOF

# 4. Create Self-Contained Import Script inside Bundle
log_info "4. Adding bundled import script (import.sh)..."
cat << 'EOF' > "${STAGING}/import.sh"
#!/usr/bin/env bash
# ==============================================================================
# Automated Invoice Ninja Production Import Script
# Usage: ./import.sh [--domain https://your-production-domain.com]
# ==============================================================================

set -euo pipefail

CLR_RESET="\033[0m"
CLR_GREEN="\033[0;32m"
CLR_YELLOW="\033[1;33m"
CLR_CYAN="\033[0;36m"
CLR_RED="\033[0;31m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_DOMAIN=""
MARIADB_CONTAINER="${MARIADB_CONTAINER:-shared_mariadb}"
INVOICENINJA_CONTAINER="${INVOICENINJA_CONTAINER:-invoiceninja_app}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain) NEW_DOMAIN="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo -e "${CLR_CYAN}==================================================${CLR_RESET}"
echo -e "${CLR_CYAN} Importing Invoice Ninja to Production            ${CLR_RESET}"
echo -e "${CLR_CYAN}==================================================${CLR_RESET}"

# 1. Detect DB password
if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    if [ -f "core-infra/.env" ]; then
        MARIADB_ROOT_PASSWORD="$(grep -E '^MARIADB_ROOT_PASSWORD=' core-infra/.env | cut -d '=' -f2- | tr -d '"'"'" || true)"
    elif [ -f "../core-infra/.env" ]; then
        MARIADB_ROOT_PASSWORD="$(grep -E '^MARIADB_ROOT_PASSWORD=' ../core-infra/.env | cut -d '=' -f2- | tr -d '"'"'" || true)"
    fi
fi

if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    echo -n "Enter MariaDB root password: "
    read -s MARIADB_ROOT_PASSWORD
    echo ""
fi

# 2. Check Docker container
if ! docker ps --format '{{.Names}}' | grep -q "^${MARIADB_CONTAINER}$"; then
    echo -e "${CLR_RED}[ERROR] MariaDB container '${MARIADB_CONTAINER}' is not running.${CLR_RESET}"
    exit 1
fi

# 3. Create database if it doesn't exist
echo -e "${CLR_CYAN}[INFO] Ensuring 'invoiceninja' database exists...${CLR_RESET}"
docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e \
    "CREATE DATABASE IF NOT EXISTS invoiceninja CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 4. Import SQL
echo -e "${CLR_CYAN}[INFO] Restoring database schema and data...${CLR_RESET}"
if [ -f "${SCRIPT_DIR}/database/invoiceninja.sql.gz" ]; then
    gunzip -c "${SCRIPT_DIR}/database/invoiceninja.sql.gz" | docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja
elif [ -f "${SCRIPT_DIR}/database/invoiceninja.sql" ]; then
    docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja < "${SCRIPT_DIR}/database/invoiceninja.sql"
else
    echo -e "${CLR_RED}[ERROR] No database dump found in ${SCRIPT_DIR}/database/${CLR_RESET}"
    exit 1
fi
echo -e "${CLR_GREEN}[✓] Database restored successfully!${CLR_RESET}"

# 5. Restore Storage
if docker ps --format '{{.Names}}' | grep -q "^${INVOICENINJA_CONTAINER}$"; then
    echo -e "${CLR_CYAN}[INFO] Restoring persistent storage files (logos, documents, PDFs)...${CLR_RESET}"
    if [ -f "${SCRIPT_DIR}/storage/storage.tar.gz" ]; then
        docker exec -i "${INVOICENINJA_CONTAINER}" tar -xzf - -C /var/www/html/storage < "${SCRIPT_DIR}/storage/storage.tar.gz"
        docker exec -i "${INVOICENINJA_CONTAINER}" chown -R www-data:www-data /var/www/html/storage
        echo -e "${CLR_GREEN}[✓] Storage files restored successfully!${CLR_RESET}"
    fi
fi

# 6. Optional domain replacement
if [ -n "${NEW_DOMAIN}" ]; then
    echo -e "${CLR_CYAN}[INFO] Updating URLs in database to: ${NEW_DOMAIN}...${CLR_RESET}"
    docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja -e \
        "UPDATE companies SET portal_domain = '${NEW_DOMAIN}' WHERE portal_domain LIKE '%localhost%';"
    docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja -e \
        "UPDATE companies SET settings = JSON_SET(settings, '$.company_logo', REPLACE(JSON_UNQUOTE(JSON_EXTRACT(settings, '$.company_logo')), 'http://erp.localhost', '${NEW_DOMAIN}'));"
    echo -e "${CLR_GREEN}[✓] Domain references updated!${CLR_RESET}"
fi

# 7. Clear application cache
if docker ps --format '{{.Names}}' | grep -q "^${INVOICENINJA_CONTAINER}$"; then
    echo -e "${CLR_CYAN}[INFO] Optimizing Laravel cache and post-update hooks...${CLR_RESET}"
    docker exec -it "${INVOICENINJA_CONTAINER}" php artisan optimize:clear || true
    docker exec -it "${INVOICENINJA_CONTAINER}" php artisan ninja:post-update || true
fi

echo -e "${CLR_GREEN}==================================================${CLR_RESET}"
echo -e "${CLR_GREEN} Invoice Ninja Production Import Complete!        ${CLR_RESET}"
echo -e "${CLR_GREEN}==================================================${CLR_RESET}"
EOF
chmod +x "${STAGING}/import.sh"

# 5. Create Manifest & README
cat <<EOF > "${STAGING}/README.txt"
==================================================
 Invoice Ninja Production Migration Package
==================================================
Created At: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Source Host: $(hostname)
APP_KEY   : ${APP_KEY}

Package Contents:
  - database/invoiceninja.sql.gz  : Full MariaDB dump of invoiceninja
  - database/invoiceninja.sql     : Uncompressed SQL dump
  - storage/storage.tar.gz        : Persistent files (company logo, PDFs, documents)
  - config/production.env.example : Ready-to-use production environment template
  - config/docker-compose.yml     : Docker Compose configuration with volume mounts
  - config/in-vhost.conf          : Nginx vhost configuration
  - import.sh                     : Automated 1-command import script

HOW TO IMPORT ON PRODUCTION:
--------------------------------------------------
Method 1: Using the bundled automated import script
  1. Extract this archive on the production server:
     tar -xzf invoiceninja-production-backup_${TIMESTAMP}.tar.gz
     cd invoiceninja-production-backup_${TIMESTAMP}

  2. Ensure your production apps/invoiceninja/.env has:
     APP_KEY=${APP_KEY}

  3. Run the import script:
     ./import.sh --domain https://erp.app.sahajananddigital.in

Method 2: Manual import
  1. Import database:
     gunzip -c database/invoiceninja.sql.gz | docker exec -i shared_mariadb mariadb -u root -p<root_password> invoiceninja

  2. Restore storage:
     docker exec -i invoiceninja_app tar -xzf - -C /var/www/html/storage < storage/storage.tar.gz

  3. Rebuild cache:
     docker exec -it invoiceninja_app php artisan optimize:clear
==================================================
EOF

# 6. Create Tarball Bundle
BUNDLE_NAME="invoiceninja-production-backup_${TIMESTAMP}.tar.gz"
BUNDLE_PATH="${OUTPUT_DIR}/${BUNDLE_NAME}"

log_info "5. Compressing migration bundle: ${BUNDLE_NAME}..."
tar -czf "${BUNDLE_PATH}" -C "${TEMP_DIR}" "invoiceninja-production-backup_${TIMESTAMP}"
BUNDLE_SIZE="$(du -h "${BUNDLE_PATH}" | cut -f1)"
log_success "Migration bundle created: ${BUNDLE_PATH} (${BUNDLE_SIZE})"

# 7. Upload to Rclone Google Drive
if [ "${DRY_RUN}" = true ]; then
    log_warn "DRY-RUN mode enabled. Skipping Rclone upload."
else
    log_info "6. Uploading to Rclone remote: ${RCLONE_REMOTE}..."
    rclone copy "${BUNDLE_PATH}" "${RCLONE_REMOTE}/" --progress --stats-one-line
    log_success "Upload completed successfully to ${RCLONE_REMOTE}/${BUNDLE_NAME}"
fi

log_info "=================================================="
log_success " Backup complete: ${BUNDLE_PATH}"
log_info "=================================================="
