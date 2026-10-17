#!/usr/bin/env bash
# ==============================================================================
# Script: create-db.sh
# Purpose: Provision an isolated MariaDB user, database, and permissions
# Target: 4GB RAM Hetzner ARM64 Docker Infrastructure (shared_mariadb)
# Usage: ./scripts/create-db.sh <app_name> <db_password>
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
    echo -e "${CLR_CYAN}[INFO]${CLR_RESET} $*"
}

log_success() {
    echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} $*"
}

log_warn() {
    echo -e "${CLR_YELLOW}[WARN]${CLR_RESET} $*"
}

log_error() {
    echo -e "${CLR_RED}[ERROR]${CLR_RESET} $*" >&2
}

# ------------------------------------------------------------------------------
# 1. Argument Validation
# ------------------------------------------------------------------------------
if [ "$#" -lt 2 ]; then
    echo -e "${CLR_BOLD}Usage:${CLR_RESET} $0 <app_name> <db_password>"
    echo -e "Example: $0 gitea SuperSecretP@ssw0rd!"
    exit 1
fi

APP_NAME="$1"
DB_PASSWORD="$2"

# Validate APP_NAME (must be safe SQL identifier: alphanumeric + underscore)
if [[ ! "${APP_NAME}" =~ ^[a-zA-Z0-9_]+$ ]]; then
    log_error "Invalid app_name '${APP_NAME}'. Only letters, numbers, and underscores are allowed."
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Check Prerequisites & Environment
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_ENV="${REPO_ROOT}/core-infra/.env"

MARIADB_ROOT_PASSWORD=""
if [ -f "${CORE_ENV}" ]; then
    # Safely extract MARIADB_ROOT_PASSWORD if present
    VAL=$(grep -E '^MARIADB_ROOT_PASSWORD=' "${CORE_ENV}" | cut -d '=' -f2- | tr -d '"'"'" || true)
    if [ -n "${VAL}" ]; then
        MARIADB_ROOT_PASSWORD="${VAL}"
    fi
fi

CONTAINER_NAME="shared_mariadb"

# Check if shared_mariadb container is running
if ! docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
    log_error "Container '${CONTAINER_NAME}' is not currently running."
    log_error "Please start the core infrastructure first:"
    echo "  cd core-infra && docker compose up -d"
    exit 1
fi

log_info "Verifying MariaDB readiness inside '${CONTAINER_NAME}'..."
MYSQL_ADMIN_CMD="mariadb-admin"
if ! docker exec "${CONTAINER_NAME}" which mariadb-admin >/dev/null 2>&1; then
    MYSQL_ADMIN_CMD="mysqladmin"
fi

if ! docker exec -i "${CONTAINER_NAME}" ${MYSQL_ADMIN_CMD} ping -u root ${MARIADB_ROOT_PASSWORD:+-p"${MARIADB_ROOT_PASSWORD}"} --silent >/dev/null 2>&1; then
    log_error "MariaDB is running but not ready to accept connections yet."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Provision Database, User & Privileges
# ------------------------------------------------------------------------------
MYSQL_CLIENT_CMD="mariadb"
if ! docker exec "${CONTAINER_NAME}" which mariadb >/dev/null 2>&1; then
    MYSQL_CLIENT_CMD="mysql"
fi

log_info "Provisioning database and user for '${APP_NAME}'..."

# Escape single quotes in password for SQL string literal
ESCAPED_DB_PASSWORD="${DB_PASSWORD//\'/\'\'}"

docker exec -i "${CONTAINER_NAME}" ${MYSQL_CLIENT_CMD} -u root ${MARIADB_ROOT_PASSWORD:+-p"${MARIADB_ROOT_PASSWORD}"} <<EOSQL >/dev/null
CREATE DATABASE IF NOT EXISTS \`${APP_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${APP_NAME}'@'%' IDENTIFIED BY '${ESCAPED_DB_PASSWORD}';
ALTER USER '${APP_NAME}'@'%' IDENTIFIED BY '${ESCAPED_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${APP_NAME}\`.* TO '${APP_NAME}'@'%';
FLUSH PRIVILEGES;
EOSQL

# ------------------------------------------------------------------------------
# 4. Success Summary
# ------------------------------------------------------------------------------
echo ""
log_success "Database '${APP_NAME}' and user '${APP_NAME}' successfully provisioned!"
echo -e "${CLR_BOLD}App Connection Details:${CLR_RESET}"
echo -e "  Host:     ${CLR_CYAN}shared_mariadb${CLR_RESET}"
echo -e "  Port:     ${CLR_CYAN}3306${CLR_RESET}"
echo -e "  Database: ${CLR_CYAN}${APP_NAME}${CLR_RESET}"
echo -e "  Username: ${CLR_CYAN}${APP_NAME}${CLR_RESET}"
echo -e "  URI:      ${CLR_CYAN}mysql://${APP_NAME}:<password>@shared_mariadb:3306/${APP_NAME}${CLR_RESET}"
