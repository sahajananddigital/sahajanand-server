#!/usr/bin/env bash
# ==============================================================================
# Script: init-server.sh
# Purpose: Idempotently initialize Docker networks and environment files
# Target: 4GB RAM Hetzner ARM64 Docker Infrastructure
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

# Determine repository root relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info "Initializing server infrastructure in: ${CLR_BOLD}${REPO_ROOT}${CLR_RESET}"

# Verify Docker availability
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is not installed or not in PATH. Please install Docker first."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not reachable. Ensure the Docker service is running."
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. External Docker Network Initialization (Idempotent)
# ------------------------------------------------------------------------------
create_network_if_missing() {
    local network_name="$1"
    if docker network inspect "${network_name}" >/dev/null 2>&1; then
        log_info "Docker network '${network_name}' already exists."
    else
        log_info "Creating Docker network '${network_name}'..."
        docker network create "${network_name}"
        log_success "Created Docker network '${network_name}'."
    fi
}

log_info "Verifying external bridge networks..."
create_network_if_missing "proxy_net"
create_network_if_missing "db_net"

# ------------------------------------------------------------------------------
# 2. Environment (.env) Scaffolding from Templates (.env.example)
# ------------------------------------------------------------------------------
log_info "Checking environment configuration files..."

CREATED_ENV_FILES=()

# Search for all .env.example files inside the repository
while IFS= read -r example_file; do
    target_env="${example_file%.example}"
    
    if [ -f "${target_env}" ]; then
        log_info "Environment file already exists: ${target_env#${REPO_ROOT}/}"
    else
        log_warn "Creating missing environment file: ${target_env#${REPO_ROOT}/} from .env.example"
        cp "${example_file}" "${target_env}"
        chmod 600 "${target_env}" # Restrict permissions to owner
        CREATED_ENV_FILES+=("${target_env}")
    fi
done < <(find "${REPO_ROOT}" -type f -name ".env.example" | sort)

# ------------------------------------------------------------------------------
# 3. Summary & Security Warning
# ------------------------------------------------------------------------------
echo ""
log_success "Server initialization completed successfully!"

if [ ${#CREATED_ENV_FILES[@]} -gt 0 ]; then
    echo -e "${CLR_YELLOW}========================================================================${CLR_RESET}"
    echo -e "${CLR_YELLOW}${CLR_BOLD}ACTION REQUIRED: DEFAULT PASSWORDS DETECTED!${CLR_RESET}"
    echo -e "${CLR_YELLOW}The following .env files were created from default templates:${CLR_RESET}"
    for env_path in "${CREATED_ENV_FILES[@]}"; do
        echo -e "  - ${CLR_BOLD}${env_path#${REPO_ROOT}/}${CLR_RESET}"
    done
    echo -e "${CLR_YELLOW}Please edit these files and replace all placeholder passwords before${CLR_RESET}"
    echo -e "${CLR_YELLOW}launching production containers!${CLR_RESET}"
    echo -e "${CLR_YELLOW}========================================================================${CLR_RESET}"
else
    log_info "All existing .env files were preserved."
fi
