#!/usr/bin/env bash
# ==============================================================================
# Script: reload-caddy.sh
# Purpose: Safely validate and reload Caddy reverse proxy with zero downtime.
# Usage: ./scripts/reload-caddy.sh [OPTIONS]
# ==============================================================================

set -euo pipefail

# ANSI Color Codes
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

CADDY_CONTAINER="${CADDY_CONTAINER:-caddy}"
CHECK_ONLY=false
SHOW_LOGS=false
SHOW_CERTS=false

show_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -c, --check     Validate Caddyfile syntax only without reloading
  -l, --logs      Show recent Caddy operational and access logs
      --certs     List active Let's Encrypt / ZeroSSL managed certificates
  -h, --help      Show this help message

Examples:
  $(basename "$0")            # Validate and reload Caddy with zero downtime
  $(basename "$0") --check    # Pre-flight syntax validation only
  $(basename "$0") --logs     # View last 50 lines of Caddy logs
  $(basename "$0") --certs    # View all active SSL certificates
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--check) CHECK_ONLY=true; shift ;;
        -l|--logs) SHOW_LOGS=true; shift ;;
        --certs) SHOW_CERTS=true; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

# Verify Docker container
if ! docker ps --format '{{.Names}}' | grep -q "^${CADDY_CONTAINER}$"; then
    log_error "Caddy container '${CADDY_CONTAINER}' is not running."
    exit 1
fi

# Show Logs Action
if [ "${SHOW_LOGS}" = true ]; then
    log_info "Displaying recent logs for '${CADDY_CONTAINER}'..."
    docker logs --tail 50 -f "${CADDY_CONTAINER}"
    exit 0
fi

# Show Certificates Action
if [ "${SHOW_CERTS}" = true ]; then
    log_info "Listing active SSL/TLS certificates stored by Caddy..."
    CERT_DIR="/data/caddy/certificates"
    if docker exec "${CADDY_CONTAINER}" test -d "${CERT_DIR}"; then
        docker exec "${CADDY_CONTAINER}" find "${CERT_DIR}" -type f -name "*.crt" | while read -r cert; do
            DOMAIN="$(basename "$(dirname "${cert}")")"
            EXPIRY="$(docker exec "${CADDY_CONTAINER}" openssl x509 -enddate -noout -in "${cert}" 2>/dev/null | cut -d '=' -f2 || echo "Unknown")"
            echo -e "  - ${CLR_BOLD}${DOMAIN}${CLR_RESET}: Expires on ${EXPIRY}"
        done
    else
        log_warn "No certificate directory found at ${CERT_DIR}."
    fi
    exit 0
fi

# Pre-flight validation
log_info "Validating Caddyfile syntax inside '${CADDY_CONTAINER}'..."
if docker exec -w /etc/caddy "${CADDY_CONTAINER}" caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1; then
    log_success "Caddyfile syntax is valid!"
else
    log_error "Caddyfile validation failed! Please check your configuration before reloading:"
    echo -e "${CLR_YELLOW}"
    docker exec -w /etc/caddy "${CADDY_CONTAINER}" caddy validate --config /etc/caddy/Caddyfile 2>&1 || true
    echo -e "${CLR_RESET}"
    exit 1
fi

if [ "${CHECK_ONLY}" = true ]; then
    log_info "Check-only mode enabled. Skipping reload."
    exit 0
fi

# Reload Caddy dynamically
log_info "Reloading Caddy with zero downtime..."
if docker exec -w /etc/caddy "${CADDY_CONTAINER}" caddy reload --config /etc/caddy/Caddyfile; then
    log_success "Caddy successfully reloaded! All routing changes are now live."
else
    log_error "Failed to reload Caddy."
    exit 1
fi
