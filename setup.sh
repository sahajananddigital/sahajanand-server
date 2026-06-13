#!/bin/bash

# Sahajanand Server Infrastructure VPS Installer & Configurator
# Automates the setup of Docker, rclone, zstd, environment config, Google Drive backup, and cron scheduling.

set -euo pipefail

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output helpers
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if run as root user
if [ "$EUID" -eq 0 ] || [ "$(id -u)" -eq 0 ]; then
    log_warn "This script must NOT be run as the root user directly."
    echo ""
    echo -n "Would you like to automatically create a secure non-root system admin user now? (y/n): "
    read -r create_sys_user
    if [[ "$create_sys_user" =~ ^[Yy]$ ]]; then
        if [ -f "create-admin-user.sh" ]; then
            bash create-admin-user.sh
            exit 0
        else
            log_error "create-admin-user.sh script not found. Cannot create user automatically."
            exit 1
        fi
    else
        log_error "Installation aborted. Please rerun as a regular user with sudo privileges: bash setup.sh"
        exit 1
    fi
fi

# Print Header
echo -e "${GREEN}"
echo "=================================================================="
echo "    Sahajanand Server VPS Installer & Backup Configurator        "
echo "=================================================================="
echo -e "${NC}"

# Check script location
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Helper to resolve environment variables containing references like ${BASE_DOMAIN}
resolve_env_var() {
    local raw_val="$1"
    if [[ "$raw_val" == *"\${BASE_DOMAIN}"* ]]; then
        local base_dom=$(grep "^BASE_DOMAIN=" .env | cut -d= -f2 || echo "localhost")
        echo "${raw_val//\$\{BASE_DOMAIN\}/$base_dom}"
    elif [[ "$raw_val" == *"\$BASE_DOMAIN"* ]]; then
        local base_dom=$(grep "^BASE_DOMAIN=" .env | cut -d= -f2 || echo "localhost")
        echo "${raw_val//\$BASE_DOMAIN/$base_dom}"
    else
        echo "$raw_val"
    fi
}

# Helper to replace or append env vars in .env
set_env_var() {
    local var_name="$1"
    local var_val="$2"
    if [ ! -f .env ]; then
        touch .env
    fi
    # If the variable exists (commented or not), replace it. Otherwise, append it.
    if grep -q "^#\?\s*${var_name}=" .env; then
        sed -i.bak "s|^#\?\s*${var_name}=.*|${var_name}=${var_val}|" .env 2>/dev/null || sed -i "" "s|^#\?\s*${var_name}=.*|${var_name}=${var_val}|" .env
    else
        echo "${var_name}=${var_val}" >> .env
    fi
}

# Check OS distribution
check_os() {
    if [ -f /etc/debian_version ]; then
        IS_DEBIAN=true
    else
        IS_DEBIAN=false
        log_warn "This script is optimized for Debian/Ubuntu systems. Package installations might need to be run manually on other distributions."
    fi
}

# Install package dependencies
install_dependencies() {
    log_info "Verifying system dependencies..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_warn "Docker is not installed."
        if [ "$IS_DEBIAN" = true ]; then
            echo -n "Would you like to install Docker now? (y/n): "
            read -r install_docker
            if [[ "$install_docker" =~ ^[Yy]$ ]]; then
                log_info "Installing Docker..."
                curl -fsSL https://get.docker.com | sh
                sudo usermod -aG docker "$USER" || true
                log_success "Docker installed successfully. (You may need to log out and back in to run docker without sudo)."
            fi
        else
            log_error "Please install Docker manually before continuing."
            exit 1
        fi
    else
        log_success "Docker is installed."
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        log_warn "Docker Compose is not installed."
        if [ "$IS_DEBIAN" = true ]; then
            echo -n "Would you like to install docker-compose-plugin now? (y/n): "
            read -r install_compose
            if [[ "$install_compose" =~ ^[Yy]$ ]]; then
                log_info "Installing Docker Compose..."
                sudo apt-get update
                sudo apt-get install -y docker-compose-plugin
                log_success "Docker Compose installed."
            fi
        else
            log_error "Please install Docker Compose manually before continuing."
            exit 1
        fi
    else
        log_success "Docker Compose is installed."
    fi

    # Check zstd
    if ! command -v zstd &> /dev/null; then
        log_warn "zstd is not installed."
        if [ "$IS_DEBIAN" = true ]; then
            log_info "Installing zstd..."
            sudo apt-get update && sudo apt-get install -y zstd
            log_success "zstd installed."
        else
            log_error "Please install zstd manually."
            exit 1
        fi
    else
        log_success "zstd is installed."
    fi

    # Check rclone
    if ! command -v rclone &> /dev/null; then
        log_warn "rclone is not installed."
        if [ "$IS_DEBIAN" = true ]; then
            echo -n "Would you like to install rclone now? (y/n): "
            read -r install_rclone
            if [[ "$install_rclone" =~ ^[Yy]$ ]]; then
                log_info "Installing rclone..."
                curl https://rclone.org/install.sh | sudo bash
                log_success "rclone installed."
            fi
        else
            log_error "Please install rclone manually."
            exit 1
        fi
    else
        log_success "rclone is installed."
    fi
}

# Setup .env file
configure_env() {
    log_info "Configuring environment files..."
    
    if [ ! -f .env ]; then
        cp .env.example .env
        log_info "Created .env file from .env.example"
    else
        log_warn ".env file already exists. We will modify it in-place."
    fi

    # 1. Environment Mode Configuration
    echo ""
    echo "Choose Environment Mode:"
    echo "1) Production (SSL certificates enabled, secure dashboard binds, automatic restarts)"
    echo "2) Local Development (HTTP only, exposed ports, no SSL, automated phpMyAdmin login)"
    echo -n "Select option [1-2, default: 1]: "
    read -r env_option
    env_option="${env_option:-1}"

    if [ "$env_option" = "2" ]; then
        log_info "Configuring for LOCAL DEVELOPMENT..."
        set_env_var "TRAEFIK_CONFIG_FILE" "traefik.yml"
        set_env_var "TRAEFIK_DASHBOARD_BIND" "8080"
        set_env_var "RESTART_POLICY" "no"
        set_env_var "PMA_USER" "root"
        set_env_var "PMA_PASSWORD" "$(grep "^MYSQL_ROOT_PASSWORD=" .env | cut -d= -f2 || echo 'rootpassword')"
        set_env_var "WEBUI_HTTP_MIDDLEWARE" "security-headers@file,gzip@file"
    else
        log_info "Configuring for PRODUCTION..."
        set_env_var "TRAEFIK_CONFIG_FILE" "traefik.prod.yml"
        set_env_var "TRAEFIK_DASHBOARD_BIND" "127.0.0.1:8080"
        set_env_var "RESTART_POLICY" "unless-stopped"
        set_env_var "PMA_USER" ""
        set_env_var "PMA_PASSWORD" ""
        set_env_var "WEBUI_HTTP_MIDDLEWARE" "redirect-to-https@file"
    fi

    # 2. Get email for Let's Encrypt
    if [ "$env_option" = "1" ]; then
        echo -n "Enter Let's Encrypt Email Address (required for SSL): "
        read -r email
        if [ -n "$email" ]; then
            set_env_var "EMAIL" "$email"
            log_info "Updated EMAIL in .env"
        fi
    fi

    # 3. Domain Settings
    echo ""
    echo "Configure Routing Domains:"
    
    current_base_domain=$(grep "^BASE_DOMAIN=" .env | cut -d= -f2 || echo "localhost")
    if [[ "$current_base_domain" == *"\${BASE_DOMAIN}"* || "$current_base_domain" == *"\$BASE_DOMAIN"* ]]; then
        current_base_domain="localhost"
    fi
    echo -n "Base Domain Name [default: $current_base_domain]: "
    read -r base_domain
    base_domain="${base_domain:-$current_base_domain}"
    set_env_var "BASE_DOMAIN" "$base_domain"
    
    current_webui_host=$(grep "^WEBUI_HOST=" .env | cut -d= -f2 || echo "webui.\${BASE_DOMAIN}")
    resolved_webui_host=$(resolve_env_var "$current_webui_host")
    echo -n "Web UI Domain [default: $resolved_webui_host]: "
    read -r webui_host
    webui_host="${webui_host:-$resolved_webui_host}"
    set_env_var "WEBUI_HOST" "$webui_host"

    current_pma_host=$(grep "^PHPMYADMIN_HOST=" .env | cut -d= -f2 || echo "phpmyadmin.\${BASE_DOMAIN}")
    resolved_pma_host=$(resolve_env_var "$current_pma_host")
    echo -n "phpMyAdmin Domain [default: $resolved_pma_host]: "
    read -r pma_host
    pma_host="${pma_host:-$resolved_pma_host}"
    set_env_var "PHPMYADMIN_HOST" "$pma_host"

    current_pla_host=$(grep "^PHPLITEADMIN_HOST=" .env | cut -d= -f2 || echo "phpliteadmin.\${BASE_DOMAIN}")
    resolved_pla_host=$(resolve_env_var "$current_pla_host")
    echo -n "phpLiteAdmin Domain [default: $resolved_pla_host]: "
    read -r pla_host
    pla_host="${pla_host:-$resolved_pla_host}"
    set_env_var "PHPLITEADMIN_HOST" "$pla_host"

    # 4. Setup MySQL Root Password (Non-Interactive Auto-Generation)
    current_root_pass=$(grep "^MYSQL_ROOT_PASSWORD=" .env | cut -d= -f2 || echo "")
    if [ -z "$current_root_pass" ] || [ "$current_root_pass" = "rootpassword" ]; then
        root_pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24)
        set_env_var "MYSQL_ROOT_PASSWORD" "$root_pass"
        if [ "$env_option" = "2" ]; then
            set_env_var "PMA_PASSWORD" "$root_pass"
        fi
        log_success "MySQL Root Password auto-generated."
    fi

    # 5. Setup default MySQL App Password (Non-Interactive Auto-Generation)
    current_app_pass=$(grep "^MYSQL_PASSWORD=" .env | cut -d= -f2 || echo "")
    if [ -z "$current_app_pass" ] || [ "$current_app_pass" = "app_password" ]; then
        app_pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24)
        set_env_var "MYSQL_PASSWORD" "$app_pass"
        log_success "Default MySQL user password auto-generated."
    fi

    # 6. Setup Web UI Admin Credentials (Non-Interactive Auto-Generation)
    if [ ! -f .webui_auth ]; then
        webui_pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
        cat > .webui_auth << EOF
WEBUI_USERNAME=admin
WEBUI_PASSWORD=$webui_pass
EOF
        chmod 600 .webui_auth
        log_success "Web UI administrator credentials auto-generated."
    fi
}

# Setup rclone remote backup
configure_rclone() {
    echo ""
    log_info "=================================================================="
    log_info "             Rclone Remote Backup Configuration                   "
    log_info "=================================================================="
    echo ""
    
    echo -n "Would you like to configure automated cloud backups with rclone now? (y/n): "
    read -r config_backups
    if [[ ! "$config_backups" =~ ^[Yy]$ ]]; then
        log_info "Skipping rclone backup configuration. You can configure this later in .env."
        return 0
    fi

    echo ""
    echo "Select your cloud backup destination:"
    echo "1) Google Drive with Service Account JSON (Highly Recommended for headless VPS)"
    echo "2) Google Drive via interactive OAuth (Requires browser authorization on your PC)"
    echo "3) Other cloud provider (S3, OneDrive, Backblaze B2, SFTP, etc. - Manual configuration)"
    echo "4) Skip / Configure later"
    echo -n "Select option [1-4]: "
    read -r backup_option

    case "$backup_option" in
        1)
            echo ""
            log_info "Setting up Google Drive with a Service Account..."
            echo "1. Go to Google Cloud Console (https://console.cloud.google.com)"
            echo "2. Create a project, enable the Google Drive API."
            echo "3. Go to IAM & Admin -> Service Accounts."
            echo "4. Create a Service Account, then select it -> Keys -> Add Key -> Create new key (JSON)."
            echo "5. Download the JSON key file."
            echo "6. Share the Google Drive target folder with the Service Account email address."
            echo ""
            echo "How would you like to provide the JSON key file?"
            echo "a) Paste the JSON file contents directly into the terminal now"
            echo "b) Provide the path to the downloaded JSON file on this server"
            echo -n "Select key option [a/b]: "
            read -r key_option

            if [ "$key_option" = "a" ] || [ "$key_option" = "A" ]; then
                log_info "Paste your Service Account JSON content below (press Ctrl+D when finished, then Enter):"
                cat > rclone-gdrive-sa.json
                chmod 600 rclone-gdrive-sa.json
                log_success "Saved Service Account JSON to rclone-gdrive-sa.json."
            else
                echo -n "Enter the absolute path to your Service Account JSON file: "
                read -r sa_path
                if [ -f "$sa_path" ]; then
                    cp "$sa_path" rclone-gdrive-sa.json
                    chmod 600 rclone-gdrive-sa.json
                    log_success "Copied Service Account JSON to rclone-gdrive-sa.json."
                else
                    log_error "File not found at: $sa_path. Skipping Google Drive config."
                    return 1
                fi
            fi

            # Configure .env variables for Google Drive Service Account
            log_info "Updating .env with Google Drive configuration..."
            set_env_var "RCLONE_REMOTE_PATH" "gdrive:Backups/sahajanand-server"
            set_env_var "RCLONE_CONFIG_GDRIVE_TYPE" "drive"
            set_env_var "RCLONE_CONFIG_GDRIVE_SCOPE" "drive"
            set_env_var "RCLONE_CONFIG_GDRIVE_SERVICE_ACCOUNT_FILE" "/var/www/project/rclone-gdrive-sa.json"
            
            log_success "Google Drive Service Account backup configured in .env."
            log_info "Default path: gdrive:Backups/sahajanand-server"
            ;;
            
        2)
            echo ""
            log_info "Setting up Google Drive via OAuth..."
            log_info "Please run the following command in a separate terminal or screen to configure the remote:"
            echo "  rclone config"
            echo "Name your remote 'gdrive' and choose Google Drive ('drive'). Follow the interactive prompts."
            echo "Because this is a VPS, you will need to run rclone on your local PC to authorize the web browser."
            echo ""
            echo -n "Press Enter once you have finished configuring rclone remote..."
            read -r
            
            set_env_var "RCLONE_REMOTE_PATH" "gdrive:Backups/sahajanand-server"
            log_success "Configured remote path 'gdrive:Backups/sahajanand-server' in .env."
            ;;

        3)
            echo ""
            log_info "Manual Rclone Remote Configuration..."
            log_info "1. Please run 'rclone config' manually to add your remote storage (S3, OneDrive, B2, Dropbox, etc.)."
            echo "2. Once configured, note down the remote name."
            echo ""
            echo -n "Enter the name of your configured rclone remote (e.g. myremote): "
            read -r rname
            echo -n "Enter the destination folder path on remote (e.g. backups/sahajanand): "
            read -r rpath
            
            if [ -n "$rname" ] && [ -n "$rpath" ]; then
                set_env_var "RCLONE_REMOTE_PATH" "${rname}:${rpath}"
                log_success "Configured remote path '${rname}:${rpath}' in .env."
            else
                log_warn "Remote name or path empty. Skipping .env update."
            fi
            ;;
            
        *)
            log_info "Skipping rclone configuration."
            ;;
    esac
}

# Configure backup cron job
configure_cron() {
    echo ""
    echo -n "Would you like to schedule a daily backup cron job at 2:00 AM? (y/n): "
    read -r schedule_cron
    if [[ "$schedule_cron" =~ ^[Yy]$ ]]; then
        # Create log dir
        mkdir -p logs
        
        cron_job="0 2 * * * /bin/bash $PROJECT_ROOT/backup.sh >> $PROJECT_ROOT/logs/backup.log 2>&1"
        
        if crontab -l 2>/dev/null | grep -Fq "backup.sh"; then
            log_info "Backup cron job already exists. Checking for changes..."
        else
            (crontab -l 2>/dev/null || true; echo "$cron_job") | crontab -
            log_success "Added daily cron job: Daily at 2:00 AM"
        fi
    fi
}

# Prepare production SSL directory
prepare_ssl() {
    log_info "Preparing SSL directory..."
    mkdir -p ssl
    touch ssl/acme.json
    chmod 600 ssl/acme.json
    log_success "SSL certificates file initialized with correct permissions."
}

# Setup phpliteadmin
setup_phpliteadmin_tool() {
    if [ -f phpliteadmin/setup.sh ]; then
        log_info "Setting up phpLiteAdmin..."
        bash phpliteadmin/setup.sh
    fi
}

# Start Docker containers
start_docker_infra() {
    # Check if the current user has write access to the docker socket
    local docker_cmd="docker"
    if [ ! -w /var/run/docker.sock ]; then
        docker_cmd="sudo docker"
        log_info "Note: Using 'sudo docker' because the current user session does not have direct write permissions to /var/run/docker.sock yet."
    fi

    echo ""
    echo -n "Would you like to start the core infrastructure (Traefik, MySQL, Redis, phpMyAdmin) now? (y/n): "
    read -r start_infra
    if [[ "$start_infra" =~ ^[Yy]$ ]]; then
        log_info "Starting Docker services..."
        $docker_cmd compose up -d
        log_success "Infrastructure containers started."
    fi

    echo ""
    echo -n "Would you like to start the Web UI Management Interface container? (y/n): "
    read -r start_webui
    if [[ "$start_webui" =~ ^[Yy]$ ]]; then
        log_info "Preparing Web UI SQLite database directory..."
        mkdir -p webui/data
        chmod 777 webui/data 2>/dev/null || true
        # Symlink root .env to webui/.env so nested docker-compose operations have access to variables
        ln -sf ../.env webui/.env
        log_info "Starting Web UI..."
        $docker_cmd compose -f webui/docker-compose.yml up -d --build
        log_success "Web UI container started."
        
        # Output access links dynamically
        local webui_domain=$(grep "^WEBUI_HOST=" .env | cut -d= -f2 || echo "webui.localhost")
        local resolved_webui=$(resolve_env_var "$webui_domain")
        log_info "You can access the Web UI at: http://${resolved_webui} (local) or https://${resolved_webui} (production)"
    fi
}

# Generate secure credentials storage file
write_credentials_file() {
    log_info "Generating secure credentials storage file..."
    
    local root_pass=$(grep "^MYSQL_ROOT_PASSWORD=" .env | cut -d= -f2 || echo "")
    local app_pass=$(grep "^MYSQL_PASSWORD=" .env | cut -d= -f2 || echo "")
    
    local webui_user="admin"
    local webui_pass=""
    if [ -f .webui_auth ]; then
        webui_user=$(grep "^WEBUI_USERNAME=" .webui_auth | cut -d= -f2 || echo "admin")
        webui_pass=$(grep "^WEBUI_PASSWORD=" .webui_auth | cut -d= -f2 || echo "Already Encrypted / Configured")
    fi
    
    local webui_domain=$(grep "^WEBUI_HOST=" .env | cut -d= -f2 || echo "webui.localhost")
    local pma_domain=$(grep "^PHPMYADMIN_HOST=" .env | cut -d= -f2 || echo "phpmyadmin.localhost")
    local pla_domain=$(grep "^PHPLITEADMIN_HOST=" .env | cut -d= -f2 || echo "phpliteadmin.localhost")

    local resolved_webui=$(resolve_env_var "$webui_domain")
    local resolved_pma=$(resolve_env_var "$pma_domain")
    local resolved_pla=$(resolve_env_var "$pla_domain")
    
    cat > credentials.txt << EOF
==================================================================
        SAHAJANAND SERVER VPS CONFIGURATION CREDENTIALS
==================================================================
Generated on: $(date)
Keep this file secure and save it in a safe place!

1. WEB MANAGEMENT INTERFACE
   URL:       http://${resolved_webui}
   Username:  ${webui_user}
   Password:  ${webui_pass}

2. MYSQL DATABASE ACCESS
   Root Username: root
   Root Password: ${root_pass}
   
   Default App User: app_user
   Default App Pass: ${app_pass}

3. ADMINISTRATIVE TOOLS
   phpMyAdmin URL:    http://${resolved_pma}
   phpLiteAdmin URL:  http://${resolved_pla}
==================================================================
EOF
    chmod 600 credentials.txt
    log_success "Credentials saved to: credentials.txt"
}

# Main script flow
main() {
    check_os
    install_dependencies
    configure_env
    configure_rclone
    configure_cron
    prepare_ssl
    setup_phpliteadmin_tool
    start_docker_infra
    
    local webui_domain=$(grep "^WEBUI_HOST=" .env | cut -d= -f2 || echo "webui.localhost")
    local pma_domain=$(grep "^PHPMYADMIN_HOST=" .env | cut -d= -f2 || echo "phpmyadmin.localhost")
    local pla_domain=$(grep "^PHPLITEADMIN_HOST=" .env | cut -d= -f2 || echo "phpliteadmin.localhost")

    local resolved_webui=$(resolve_env_var "$webui_domain")
    local resolved_pma=$(resolve_env_var "$pma_domain")
    local resolved_pla=$(resolve_env_var "$pla_domain")

    write_credentials_file

    local root_pass=$(grep "^MYSQL_ROOT_PASSWORD=" .env | cut -d= -f2 || echo "")
    local webui_user="admin"
    local webui_pass=""
    if [ -f .webui_auth ]; then
        webui_user=$(grep "^WEBUI_USERNAME=" .webui_auth | cut -d= -f2 || echo "admin")
        webui_pass=$(grep "^WEBUI_PASSWORD=" .webui_auth | cut -d= -f2 || echo "Already Configured")
    fi

    echo ""
    echo -e "${GREEN}==================================================================${NC}"
    log_success "          Sahajanand Server setup completed!              "
    echo -e "${GREEN}==================================================================${NC}"
    echo -e "  Web Management UI:   ${BLUE}http://${resolved_webui}${NC}"
    echo -e "    Username:          ${BLUE}${webui_user}${NC}"
    echo -e "    Password:          ${YELLOW}${webui_pass}${NC}"
    echo ""
    echo -e "  MySQL Root Password: ${YELLOW}${root_pass}${NC}"
    echo -e "  phpMyAdmin URL:      http://${resolved_pma}"
    echo -e "  phpLiteAdmin URL:    http://${resolved_pla}"
    echo -e "${GREEN}==================================================================${NC}"
    echo -e "  Credentials file:    ${GREEN}credentials.txt${NC}"
    echo -e "${GREEN}==================================================================${NC}"
    echo "Next steps:"
    echo "  1. If you didn't start the services, do so via: "
    echo "     docker compose up -d"
    echo "  2. Deploy your clients inside the 'clients/' directory."
    echo "  3. Check backup logs at: tail -f logs/backup.log"
    echo "=================================================================="
    echo ""
}

main
