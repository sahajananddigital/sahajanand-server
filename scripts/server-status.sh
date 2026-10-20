#!/usr/bin/env bash
# ==============================================================================
# Script: server-status.sh
# Purpose: Interactive status dashboard displaying container health, memory
#          budget consumption, database connectivity, and system disk space.
# Usage: ./scripts/server-status.sh
# ==============================================================================

set -euo pipefail

# ANSI Color Codes
CLR_RESET="\033[0m"
CLR_RED="\033[0;31m"
CLR_GREEN="\033[0;32m"
CLR_YELLOW="\033[1;33m"
CLR_CYAN="\033[0;36m"
CLR_BOLD="\033[1m"
CLR_MAGENTA="\033[0;35m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${CLR_CYAN}${CLR_BOLD}========================================================================${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}             Hetzner Infrastructure Health Dashboard                    ${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}========================================================================${CLR_RESET}"
echo -e "Hostname: ${CLR_BOLD}$(hostname)${CLR_RESET} | Date: ${CLR_BOLD}$(date '+%Y-%m-%d %H:%M:%S')${CLR_RESET}"
echo ""

# 1. System Resources (RAM & Disk)
echo -e "${CLR_BOLD}[1. System Host Resources]${CLR_RESET}"
if command -v free >/dev/null 2>&1; then
    free -h | awk 'NR<=2 {print "  " $0}'
else
    # macOS fallback
    TOTAL_RAM="$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f GB", $1/1024/1024/1024}' || echo "N/A")"
    echo -e "  Host Physical Memory: ${CLR_BOLD}${TOTAL_RAM}${CLR_RESET}"
fi
echo -n "  Root Filesystem Disk: "
df -h / | awk 'NR==2 {print $3 " used / " $2 " total (" $5 " full)"}'
echo ""

# 2. Core Service Connectivity Checks
echo -e "${CLR_BOLD}[2. Core Infrastructure Status]${CLR_RESET}"

# MariaDB Check
if docker ps --format '{{.Names}}' | grep -q "^shared_mariadb$"; then
    if docker exec shared_mariadb mariadb-admin ping -h localhost --silent >/dev/null 2>&1; then
        echo -e "  - MariaDB (shared_mariadb) : ${CLR_GREEN}● ONLINE (Ready for queries)${CLR_RESET}"
    else
        echo -e "  - MariaDB (shared_mariadb) : ${CLR_YELLOW}▲ STARTING / UNHEALTHY${CLR_RESET}"
    fi
else
    echo -e "  - MariaDB (shared_mariadb) : ${CLR_RED}✖ OFFLINE${CLR_RESET}"
fi

# Redis Check
if docker ps --format '{{.Names}}' | grep -q "^shared_redis$"; then
    if [ "$(docker exec shared_redis redis-cli ping 2>/dev/null)" = "PONG" ]; then
        echo -e "  - Redis Cache (shared_redis) : ${CLR_GREEN}● ONLINE (PONG)${CLR_RESET}"
    else
        echo -e "  - Redis Cache (shared_redis) : ${CLR_YELLOW}▲ UNRESPONSIVE${CLR_RESET}"
    fi
else
    echo -e "  - Redis Cache (shared_redis) : ${CLR_RED}✖ OFFLINE${CLR_RESET}"
fi

# Caddy Check
if docker ps --format '{{.Names}}' | grep -q "^caddy$"; then
    echo -e "  - Reverse Proxy (caddy)      : ${CLR_GREEN}● ONLINE (Reverse Proxying Active)${CLR_RESET}"
else
    echo -e "  - Reverse Proxy (caddy)      : ${CLR_RED}✖ OFFLINE${CLR_RESET}"
fi
echo ""

# 3. Active Applications & URLs
echo -e "${CLR_BOLD}[3. Active Application Stacks]${CLR_RESET}"
printf "  %-20s %-15s %-35s\n" "APPLICATION" "STATUS" "LOCAL / PROD URL"
printf "  %-20s %-15s %-35s\n" "--------------------" "---------------" "-----------------------------------"

check_app_row() {
    local name="$1"
    local container="$2"
    local local_url="$3"

    local status_display
    if docker ps --format '{{.Names}} {{.Status}}' | grep -q "^${container} "; then
        local raw_status="$(docker ps --filter "name=^${container}$" --format "{{.Status}}")"
        if echo "${raw_status}" | grep -q "(healthy)"; then
            status_display="${CLR_GREEN}Healthy${CLR_RESET}"
        else
            status_display="${CLR_GREEN}Running${CLR_RESET}"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        status_display="${CLR_RED}Exited${CLR_RESET}"
    else
        status_display="${CLR_YELLOW}Not Installed${CLR_RESET}"
    fi

    printf "  %-20s %-24b %-35s\n" "${name}" "${status_display}" "${local_url}"
}

check_app_row "Invoice Ninja" "invoiceninja_app" "http://erp.localhost"
check_app_row "FreeScout Helpdesk" "freescout" "http://help.localhost"
check_app_row "Gitea Git Server" "gitea" "http://git.localhost"
check_app_row "Uptime Kuma" "uptime_kuma" "http://status.localhost"
check_app_row "OpenWA Gateway" "openwa" "http://wa.localhost"
echo ""

# 4. Memory Budget & Utilization
echo -e "${CLR_BOLD}[4. Memory Budget vs Real Consumption]${CLR_RESET}"
docker stats --no-stream --format "table   {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo -e "${CLR_CYAN}Run './scripts/reload-caddy.sh' to reload routing rules without downtime.${CLR_RESET}"
echo -e "${CLR_CYAN}Run './scripts/backup-rclone.sh' to perform automated cloud backup.${CLR_RESET}"
echo -e "${CLR_CYAN}Run './scripts/clean-docker.sh' to safely reclaim unused disk space.${CLR_RESET}"
echo -e "${CLR_CYAN}${CLR_BOLD}========================================================================${CLR_RESET}"
