#!/usr/bin/env bash
# ==============================================================================
# Script: create-db.sh
# Purpose: Provision an isolated PostgreSQL user, database, and permissions
# Target: 4GB RAM Hetzner ARM64 Docker Infrastructure (shared_postgres)
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

POSTGRES_ROOT_USER="postgres"
if [ -f "${CORE_ENV}" ]; then
    # Safely extract POSTGRES_ROOT_USER if present
    VAL=$(grep -E '^POSTGRES_ROOT_USER=' "${CORE_ENV}" | cut -d '=' -f2- | tr -d '"'"'" || true)
    if [ -n "${VAL}" ]; then
        POSTGRES_ROOT_USER="${VAL}"
    fi
fi

CONTAINER_NAME="shared_postgres"

# Check if shared_postgres container is running
if ! docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
    log_error "Container '${CONTAINER_NAME}' is not currently running."
    log_error "Please start the core infrastructure first:"
    echo "  cd core-infra && docker compose up -d"
    exit 1
fi

log_info "Verifying PostgreSQL readiness inside '${CONTAINER_NAME}'..."
if ! docker exec -i "${CONTAINER_NAME}" pg_isready -U "${POSTGRES_ROOT_USER}" >/dev/null 2>&1; then
    log_error "PostgreSQL is running but not ready to accept connections yet."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Provision Role & Database
# ------------------------------------------------------------------------------
log_info "Creating / Updating role '${APP_NAME}'..."
docker exec -i "${CONTAINER_NAME}" psql -U "${POSTGRES_ROOT_USER}" -d postgres <<EOSQL >/dev/null
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${APP_NAME}') THEN
        CREATE ROLE "${APP_NAME}" WITH LOGIN PASSWORD '${DB_PASSWORD}';
    ELSE
        ALTER ROLE "${APP_NAME}" WITH PASSWORD '${DB_PASSWORD}';
    END IF;
END
\$\$;
EOSQL

log_info "Checking if database '${APP_NAME}' exists..."
DB_EXISTS=$(docker exec -i "${CONTAINER_NAME}" psql -U "${POSTGRES_ROOT_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${APP_NAME}';" || true)

if [ "${DB_EXISTS}" != "1" ]; then
    log_info "Creating database '${APP_NAME}' owned by '${APP_NAME}'..."
    docker exec -i "${CONTAINER_NAME}" psql -U "${POSTGRES_ROOT_USER}" -d postgres -c "CREATE DATABASE \"${APP_NAME}\" OWNER \"${APP_NAME}\";" >/dev/null
else
    log_info "Database '${APP_NAME}' already exists. Updating ownership..."
    docker exec -i "${CONTAINER_NAME}" psql -U "${POSTGRES_ROOT_USER}" -d postgres -c "ALTER DATABASE \"${APP_NAME}\" OWNER TO \"${APP_NAME}\";" >/dev/null
fi

log_info "Configuring privileges and schema ownership for '${APP_NAME}'..."
docker exec -i "${CONTAINER_NAME}" psql -U "${POSTGRES_ROOT_USER}" -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"${APP_NAME}\" TO \"${APP_NAME}\";" >/dev/null
# Grant schema permissions in Postgres 15+
docker exec -i "${CONTAINER_NAME}" psql -U "${POSTGRES_ROOT_USER}" -d "${APP_NAME}" -c "GRANT ALL ON SCHEMA public TO \"${APP_NAME}\";" >/dev/null

# ------------------------------------------------------------------------------
# 4. Success Summary
# ------------------------------------------------------------------------------
echo ""
log_success "Database '${APP_NAME}' and role '${APP_NAME}' successfully provisioned!"
echo -e "${CLR_BOLD}App Connection Details:${CLR_RESET}"
echo -e "  Host:     ${CLR_CYAN}shared_postgres${CLR_RESET}"
echo -e "  Port:     ${CLR_CYAN}5432${CLR_RESET}"
echo -e "  Database: ${CLR_CYAN}${APP_NAME}${CLR_RESET}"
echo -e "  Username: ${CLR_CYAN}${APP_NAME}${CLR_RESET}"
echo -e "  URI:      ${CLR_CYAN}postgresql://${APP_NAME}:<password>@shared_postgres:5432/${APP_NAME}${CLR_RESET}"
