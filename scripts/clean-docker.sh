#!/usr/bin/env bash
# ==============================================================================
# Script: clean-docker.sh
# Purpose: Safe Docker disk cleanup and pruning for Hetzner VPS with limited SSD.
#          Reclaims disk space from dangling images, stopped build caches, and
#          stale layers WITHOUT deleting database or persistent volumes.
# Usage: ./scripts/clean-docker.sh [OPTIONS]
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

DEEP_CLEAN=false

show_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --deep        Also prune unused images older than 7 days (168h)
  -h, --help    Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deep) DEEP_CLEAN=true; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) shift ;;
    esac
done

echo -e "${CLR_CYAN}${CLR_BOLD}========================================================================${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}             Safe Docker Disk Space Cleanup & Maintenance               ${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}========================================================================${CLR_RESET}"

log_info "1. Current Docker Disk Utilization:"
docker system df
echo ""

log_info "2. Pruning stopped containers, unused networks, and dangling images..."
docker system prune -f

if [ "${DEEP_CLEAN}" = true ]; then
    log_info "3. Deep Clean: Removing unused images older than 7 days (168h)..."
    docker image prune -a --filter "until=168h" -f
fi

echo ""
log_info "4. Updated Docker Disk Utilization:"
docker system df

echo ""
log_success "Cleanup completed safely! (Persistent database and app volumes were untouched)."
echo -e "${CLR_CYAN}${CLR_BOLD}========================================================================${CLR_RESET}"
