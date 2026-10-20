#!/usr/bin/env bash
# ==============================================================================
# Script: restore-invoiceninja.sh
# Purpose: Import an Invoice Ninja production migration bundle or database dump
#          into the local/production Docker environment.
# Usage: ./scripts/restore-invoiceninja.sh <backup_archive.tar.gz | backup.sql.gz> [OPTIONS]
# ==============================================================================

set -euo pipefail

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

BACKUP_FILE="${1:-}"
NEW_DOMAIN=""
MARIADB_CONTAINER="${MARIADB_CONTAINER:-shared_mariadb}"
INVOICENINJA_CONTAINER="${INVOICENINJA_CONTAINER:-invoiceninja_app}"

show_usage() {
    cat <<EOF
Usage: $(basename "$0") <BACKUP_FILE> [OPTIONS]

Arguments:
  <BACKUP_FILE>         Path to invoiceninja-production-backup_*.tar.gz or .sql.gz

Options:
  --domain <url>        Production domain URL to update in database
                        (e.g. https://erp.app.sahajananddigital.in)
  -h, --help            Show this help message

Example:
  $(basename "$0") backups/invoiceninja-production-backup_2026-10-20.tar.gz --domain https://erp.app.sahajananddigital.in
EOF
}

if [ -z "${BACKUP_FILE}" ] || [ "${BACKUP_FILE}" = "-h" ] || [ "${BACKUP_FILE}" = "--help" ]; then
    show_usage
    exit 0
fi

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain) NEW_DOMAIN="$2"; shift 2 ;;
        -h|--help) show_usage; exit 0 ;;
        *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

if [ ! -f "${BACKUP_FILE}" ]; then
    log_error "Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

log_info "=================================================="
log_info " Starting Invoice Ninja Production Import"
log_info " Target: ${BACKUP_FILE}"
log_info "=================================================="

# 1. Load MariaDB root password
if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    CORE_ENV="${REPO_ROOT}/core-infra/.env"
    if [ -f "${CORE_ENV}" ]; then
        MARIADB_ROOT_PASSWORD="$(grep -E '^MARIADB_ROOT_PASSWORD=' "${CORE_ENV}" | cut -d '=' -f2- | tr -d '"'"'" || true)"
    fi
fi

if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    echo -n "Enter MariaDB root password: "
    read -s MARIADB_ROOT_PASSWORD
    echo ""
fi
[ -n "${MARIADB_ROOT_PASSWORD:-}" ] || { log_error "MARIADB_ROOT_PASSWORD is required."; exit 1; }

# 2. Verify containers
docker ps --format '{{.Names}}' | grep -q "^${MARIADB_CONTAINER}$" || { log_error "${MARIADB_CONTAINER} is not running."; exit 1; }

# 3. Create database if missing
log_info "Ensuring 'invoiceninja' database exists..."
docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e \
    "CREATE DATABASE IF NOT EXISTS invoiceninja CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 4. Handle Archive Bundle or Plain SQL
TEMP_EXTRACT_DIR=""
cleanup() { [ -n "${TEMP_EXTRACT_DIR}" ] && [ -d "${TEMP_EXTRACT_DIR}" ] && rm -rf "${TEMP_EXTRACT_DIR}"; }
trap cleanup EXIT

SQL_TO_RESTORE=""
STORAGE_TO_RESTORE=""

if [[ "${BACKUP_FILE}" == *.tar.gz ]] || [[ "${BACKUP_FILE}" == *.tgz ]]; then
    log_info "Extracting backup bundle to temporary staging area..."
    TEMP_EXTRACT_DIR="$(mktemp -d -t in_restore_XXXXXX)"
    tar -xzf "${BACKUP_FILE}" -C "${TEMP_EXTRACT_DIR}"

    # Search for SQL dump
    SQL_TO_RESTORE="$(find "${TEMP_EXTRACT_DIR}" -type f -name "*.sql" -o -name "*.sql.gz" | head -n 1)"
    # Search for storage tarball
    STORAGE_TO_RESTORE="$(find "${TEMP_EXTRACT_DIR}" -type f -name "*storage*.tar.gz" | head -n 1)"

    # Print manifest/README if found
    MANIFEST_FILE="$(find "${TEMP_EXTRACT_DIR}" -type f -name "README.txt" -o -name "manifest.txt" | head -n 1)"
    if [ -n "${MANIFEST_FILE}" ] && [ -f "${MANIFEST_FILE}" ]; then
        echo -e "${CLR_YELLOW}"
        cat "${MANIFEST_FILE}"
        echo -e "${CLR_RESET}"
    fi
elif [[ "${BACKUP_FILE}" == *.sql ]] || [[ "${BACKUP_FILE}" == *.sql.gz ]]; then
    SQL_TO_RESTORE="${BACKUP_FILE}"
fi

# 5. Restore Database
if [ -n "${SQL_TO_RESTORE}" ] && [ -f "${SQL_TO_RESTORE}" ]; then
    log_info "Restoring MariaDB database from: ${SQL_TO_RESTORE}..."
    if [[ "${SQL_TO_RESTORE}" == *.gz ]]; then
        gunzip -c "${SQL_TO_RESTORE}" | docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja
    else
        docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja < "${SQL_TO_RESTORE}"
    fi
    log_success "Database restored successfully!"
else
    log_error "No valid SQL dump found inside ${BACKUP_FILE}"
    exit 1
fi

# 6. Restore Storage Files
if [ -n "${STORAGE_TO_RESTORE}" ] && [ -f "${STORAGE_TO_RESTORE}" ]; then
    if docker ps --format '{{.Names}}' | grep -q "^${INVOICENINJA_CONTAINER}$"; then
        log_info "Restoring persistent storage from: ${STORAGE_TO_RESTORE}..."
        docker exec -i "${INVOICENINJA_CONTAINER}" tar -xzf - -C /var/www/html/storage < "${STORAGE_TO_RESTORE}"
        docker exec -i "${INVOICENINJA_CONTAINER}" chown -R www-data:www-data /var/www/html/storage
        log_success "Persistent storage (logos, PDFs, uploads) restored successfully!"
    else
        log_warn "Container '${INVOICENINJA_CONTAINER}' is not running. Storage files could not be extracted directly."
    fi
fi

# 7. Update Domain (if requested)
if [ -n "${NEW_DOMAIN}" ]; then
    log_info "Updating domain references in database to: ${NEW_DOMAIN}..."
    docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja -e \
        "UPDATE companies SET portal_domain = '${NEW_DOMAIN}' WHERE portal_domain LIKE '%localhost%';"
    docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja -e \
        "UPDATE companies SET settings = JSON_SET(settings, '$.company_logo', REPLACE(JSON_UNQUOTE(JSON_EXTRACT(settings, '$.company_logo')), 'http://erp.localhost', '${NEW_DOMAIN}'));"
    log_success "Updated portal_domain and company_logo URLs in companies settings!"
fi

# 8. Clear Cache and Run Post-Update
if docker ps --format '{{.Names}}' | grep -q "^${INVOICENINJA_CONTAINER}$"; then
    log_info "Rebuilding Laravel cache and refreshing internal routes..."
    docker exec -it "${INVOICENINJA_CONTAINER}" php artisan optimize:clear || true
    docker exec -it "${INVOICENINJA_CONTAINER}" php artisan ninja:post-update || true
fi

# 9. Verify Final Counts
log_info "Verifying restored entity counts in Invoice Ninja..."
docker exec -i "${MARIADB_CONTAINER}" mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" invoiceninja -e "
SELECT 'Clients' as Entity, count(*) as Count FROM clients WHERE is_deleted = 0
UNION ALL
SELECT 'Invoices' as Entity, count(*) as Count FROM invoices WHERE is_deleted = 0
UNION ALL
SELECT 'Payments' as Entity, count(*) as Count FROM payments WHERE is_deleted = 0
UNION ALL
SELECT 'Expenses' as Entity, count(*) as Count FROM expenses WHERE is_deleted = 0
UNION ALL
SELECT 'Bank Accounts' as Entity, count(*) as Count FROM bank_integrations WHERE is_deleted = 0;
"

log_info "=================================================="
log_success " Invoice Ninja import completed successfully!"
log_info "=================================================="
