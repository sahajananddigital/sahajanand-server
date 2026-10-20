#!/usr/bin/env bash
# ==============================================================================
# Script: update-app.sh
# Purpose: Zero-downtime, idempotent updates for specific application stacks.
#          Pulls the latest images and recreates containers without interrupting
#          other running stacks on the server.
# Usage: ./scripts/update-app.sh <app_name | all>
# ==============================================================================

set -euo pipefail

CLR_RESET="\033[0m"
CLR_RED="\033[0;31m"
CLR_GREEN="\033[0;32m"
CLR_YELLOW="\033[1;33m"
CLR_CYAN="\033[0;36m"
CLR_BOLD="\033[1m"

log_info() { echo -e "${CLR_CYAN}[INFO]${CLR_RESET} $*"; }
log_success() { echo -e "${CLR_GREEN}[SUCCESS]${CLR_RESET} $*"; }
log_warn() { echo -e "${CLR_YELLOW}[WARN]${CLR_RESET} $*"; }
log_error() { echo -e "${CLR_RED}[ERROR]${CLR_RESET} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET="${1:-}"

show_usage() {
    cat <<EOF
Usage: $(basename "$0") <app_name | all>

Supported Targets:
  core            Core platform (Caddy, MariaDB, Redis)
  invoiceninja    Invoice Ninja billing stack
  freescout       FreeScout help desk & shared inbox
  gitea           Gitea Git service
  uptime-kuma     Uptime Kuma monitoring service
  openwa          OpenWA WhatsApp gateway
  all             Pull and update all running stacks sequentially

Example:
  $(basename "$0") freescout
  $(basename "$0") invoiceninja
  $(basename "$0") all
EOF
}

if [ -z "${TARGET}" ] || [ "${TARGET}" = "-h" ] || [ "${TARGET}" = "--help" ]; then
    show_usage
    exit 0
fi

update_stack() {
    local name="$1"
    local dir="$2"

    if [ ! -d "${dir}" ] || [ ! -f "${dir}/docker-compose.yml" ]; then
        log_warn "Directory '${dir}' not found or has no docker-compose.yml. Skipping ${name}."
        return
    fi

    echo -e "${CLR_CYAN}${CLR_BOLD}>>> Updating Stack: ${name} (${dir#${REPO_ROOT}/})${CLR_RESET}"
    cd "${dir}"
    
    log_info "Pulling latest image for ${name}..."
    docker compose pull

    log_info "Recreating containers with zero-downtime..."
    docker compose up -d

    log_success "Stack '${name}' updated successfully!"
    echo ""
}

case "${TARGET}" in
    core|caddy|mariadb|redis)
        update_stack "Core Infrastructure" "${REPO_ROOT}/core-infra"
        ;;
    invoiceninja|ninja)
        update_stack "Invoice Ninja" "${REPO_ROOT}/apps/invoiceninja"
        ;;
    freescout)
        update_stack "FreeScout" "${REPO_ROOT}/apps/freescout"
        ;;
    gitea)
        update_stack "Gitea" "${REPO_ROOT}/apps/gitea"
        ;;
    uptime-kuma|kuma|uptime)
        update_stack "Uptime Kuma" "${REPO_ROOT}/apps/uptime-kuma"
        ;;
    openwa|wa)
        update_stack "OpenWA" "${REPO_ROOT}/apps/openwa"
        ;;
    all)
        log_info "Updating all infrastructure and application stacks..."
        update_stack "Core Infrastructure" "${REPO_ROOT}/core-infra"
        update_stack "Gitea" "${REPO_ROOT}/apps/gitea"
        update_stack "Uptime Kuma" "${REPO_ROOT}/apps/uptime-kuma"
        update_stack "OpenWA" "${REPO_ROOT}/apps/openwa"
        update_stack "Invoice Ninja" "${REPO_ROOT}/apps/invoiceninja"
        update_stack "FreeScout" "${REPO_ROOT}/apps/freescout"
        log_success "All application stacks updated successfully!"
        ;;
    *)
        log_error "Unknown application target: ${TARGET}"
        show_usage
        exit 1
        ;;
esac
