<?php
/**
 * Configuration file for Web UI
 */

// Project root directory
// In Docker, project root is mounted at /var/www/project
// On host, calculate from current file location
$isDocker = file_exists('/.dockerenv');
if ($isDocker) {
    define('PROJECT_ROOT', '/var/www/project');
} else {
    define('PROJECT_ROOT', dirname(__DIR__, 2));
}

define('CLIENTS_DIR', $isDocker ? '/var/www/clients' : (PROJECT_ROOT . '/clients'));
define('MYSQL_DIR', $isDocker ? '/var/www/mysql' : (PROJECT_ROOT . '/mysql'));
define('BACKUP_DIR', getenv('BACKUP_DIR') ?: '/tmp/sahajanand-backups');
define('BACKUP_SCRIPT', $isDocker ? '/var/www/backup.sh' : (PROJECT_ROOT . '/backup.sh'));

// Docker socket for Docker API
define('DOCKER_SOCKET', $isDocker ? 'unix:///var/run/docker.sock' : 'unix:///var/run/docker.sock');

// Timezone
date_default_timezone_set('UTC');

// Error reporting (disable in production)
error_reporting(E_ALL);
ini_set('display_errors', 0);

/**
 * Get MySQL root password from environment or .env file
 */
function get_mysql_root_password() {
    // Try environment variable first
    if (!empty($_ENV['MYSQL_ROOT_PASSWORD'])) {
        return $_ENV['MYSQL_ROOT_PASSWORD'];
    }
    
    // Try .env file
    $env_file = PROJECT_ROOT . '/.env';
    if (file_exists($env_file)) {
        $lines = file($env_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (preg_match('/^\s*MYSQL_ROOT_PASSWORD\s*=\s*(.+?)\s*$/', $line, $matches)) {
                return trim($matches[1], '"\'');
            }
        }
    }
    
    // Default fallback (should be changed in production)
    return 'rootpassword';
}
