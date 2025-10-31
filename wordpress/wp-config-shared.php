<?php
/**
 * Shared WordPress Configuration
 * This file is shared across all clients
 */

// Database configuration - will be overridden by client-specific config
if (!defined('DB_NAME')) {
    define('DB_NAME', 'wordpress');
}
if (!defined('DB_USER')) {
    define('DB_USER', 'wordpress');
}
if (!defined('DB_PASSWORD')) {
    define('DB_PASSWORD', '');
}
if (!defined('DB_HOST')) {
    define('DB_HOST', 'localhost:3306');
}
if (!defined('DB_CHARSET')) {
    define('DB_CHARSET', 'utf8mb4');
}
if (!defined('DB_COLLATE')) {
    define('DB_COLLATE', 'utf8mb4_unicode_ci');
}

// Authentication keys and salts - should be unique per client
if (!defined('AUTH_KEY')) {
    define('AUTH_KEY', 'your-auth-key-here');
}
if (!defined('SECURE_AUTH_KEY')) {
    define('SECURE_AUTH_KEY', 'your-secure-auth-key-here');
}
if (!defined('LOGGED_IN_KEY')) {
    define('LOGGED_IN_KEY', 'your-logged-in-key-here');
}
if (!defined('NONCE_KEY')) {
    define('NONCE_KEY', 'your-nonce-key-here');
}
if (!defined('AUTH_SALT')) {
    define('AUTH_SALT', 'your-auth-salt-here');
}
if (!defined('SECURE_AUTH_SALT')) {
    define('SECURE_AUTH_SALT', 'your-secure-auth-salt-here');
}
if (!defined('LOGGED_IN_SALT')) {
    define('LOGGED_IN_SALT', 'your-logged-in-salt-here');
}
if (!defined('NONCE_SALT')) {
    define('NONCE_SALT', 'your-nonce-salt-here');
}

// WordPress configuration
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '256M');
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);

// Security
define('DISALLOW_FILE_EDIT', true);
define('FORCE_SSL_ADMIN', true);

// Performance
define('WP_POST_REVISIONS', 3);
define('AUTOSAVE_INTERVAL', 300);
define('WP_CRON_LOCK_TIMEOUT', 60);

// File system
define('FS_METHOD', 'direct');
define('FS_CHMOD_DIR', 0755);
define('FS_CHMOD_FILE', 0644);

// Redis configuration - will be overridden by client-specific config
if (!defined('WP_REDIS_HOST')) {
    define('WP_REDIS_HOST', 'redis');
}
if (!defined('WP_REDIS_PORT')) {
    define('WP_REDIS_PORT', 6379);
}
if (!defined('WP_REDIS_DATABASE')) {
    define('WP_REDIS_DATABASE', 0);
}
if (!defined('WP_REDIS_PREFIX')) {
    define('WP_REDIS_PREFIX', 'wp:');
}

// Load WordPress
if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

// Only load WordPress if not already loaded
if (!function_exists('wp_get_current_user')) {
    require_once(ABSPATH . 'wp-settings.php');
}
