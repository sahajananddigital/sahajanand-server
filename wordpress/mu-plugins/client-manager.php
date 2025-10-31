<?php
/**
 * Client Management MU Plugin
 * Provides centralized management features for all clients
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Ensure WordPress is loaded
if (!function_exists('add_action')) {
    return;
}

class Client_Manager {
    
    public function __construct() {
        add_action('init', array($this, 'init'));
        add_action('admin_menu', array($this, 'add_admin_menu'));
        add_action('wp_ajax_client_health_check', array($this, 'health_check'));
        add_action('wp_ajax_client_cache_flush', array($this, 'flush_cache'));
        add_action('wp_ajax_client_backup', array($this, 'create_backup'));
    }
    
    public function init() {
        // Add client identification
        $this->add_client_identification();
        
        // Add security headers
        $this->add_security_headers();
        
        // Add performance optimizations
        $this->add_performance_optimizations();
    }
    
    private function add_client_identification() {
        // Add client name to admin bar
        add_action('admin_bar_menu', array($this, 'add_client_to_admin_bar'), 999);
        
        // Add client info to admin footer
        add_filter('admin_footer_text', array($this, 'add_client_info_to_footer'));
    }
    
    public function add_client_to_admin_bar($wp_admin_bar) {
        $client_name = get_option('client_name', 'Unknown Client');
        $wp_admin_bar->add_node(array(
            'id' => 'client-info',
            'title' => 'Client: ' . $client_name,
            'href' => admin_url('admin.php?page=client-manager'),
        ));
    }
    
    public function add_client_info_to_footer($text) {
        $client_name = get_option('client_name', 'Unknown Client');
        $client_domain = get_option('client_domain', 'Unknown Domain');
        return $text . ' | Client: ' . $client_name . ' (' . $client_domain . ')';
    }
    
    private function add_security_headers() {
        // Add security headers
        add_action('send_headers', function() {
            header('X-Content-Type-Options: nosniff');
            header('X-Frame-Options: SAMEORIGIN');
            header('X-XSS-Protection: 1; mode=block');
            header('Referrer-Policy: strict-origin-when-cross-origin');
        });
    }
    
    private function add_performance_optimizations() {
        // Optimize database queries
        add_action('init', function() {
            // Remove unnecessary queries
            remove_action('wp_head', 'wp_generator');
            remove_action('wp_head', 'wlwmanifest_link');
            remove_action('wp_head', 'rsd_link');
            remove_action('wp_head', 'wp_shortlink_wp_head');
        });
        
        // Optimize images
        add_filter('jpeg_quality', function($quality) {
            return 85; // Reduce image quality for better performance
        });
    }
    
    public function add_admin_menu() {
        add_menu_page(
            'Client Manager',
            'Client Manager',
            'manage_options',
            'client-manager',
            array($this, 'admin_page'),
            'dashicons-admin-tools',
            30
        );
    }
    
    public function admin_page() {
        $client_name = get_option('client_name', 'Unknown Client');
        $client_domain = get_option('client_domain', 'Unknown Domain');
        $wp_version = get_bloginfo('version');
        $php_version = PHP_VERSION;
        $memory_limit = ini_get('memory_limit');
        $max_execution_time = ini_get('max_execution_time');
        
        ?>
        <div class="wrap">
            <h1>Client Manager</h1>
            
            <div class="card">
                <h2>Client Information</h2>
                <table class="form-table">
                    <tr>
                        <th>Client Name:</th>
                        <td><?php echo esc_html($client_name); ?></td>
                    </tr>
                    <tr>
                        <th>Domain:</th>
                        <td><?php echo esc_html($client_domain); ?></td>
                    </tr>
                    <tr>
                        <th>WordPress Version:</th>
                        <td><?php echo esc_html($wp_version); ?></td>
                    </tr>
                    <tr>
                        <th>PHP Version:</th>
                        <td><?php echo esc_html($php_version); ?></td>
                    </tr>
                    <tr>
                        <th>Memory Limit:</th>
                        <td><?php echo esc_html($memory_limit); ?></td>
                    </tr>
                    <tr>
                        <th>Max Execution Time:</th>
                        <td><?php echo esc_html($max_execution_time); ?>s</td>
                    </tr>
                </table>
            </div>
            
            <div class="card">
                <h2>Quick Actions</h2>
                <p>
                    <button type="button" class="button button-primary" onclick="healthCheck()">Health Check</button>
                    <button type="button" class="button" onclick="flushCache()">Flush Cache</button>
                    <button type="button" class="button" onclick="createBackup()">Create Backup</button>
                </p>
                <div id="action-result"></div>
            </div>
            
            <div class="card">
                <h2>System Status</h2>
                <div id="system-status">
                    <p>Click "Health Check" to see system status.</p>
                </div>
            </div>
        </div>
        
        <script>
        function healthCheck() {
            document.getElementById('action-result').innerHTML = '<p>Running health check...</p>';
            fetch(ajaxurl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: 'action=client_health_check&nonce=' + '<?php echo wp_create_nonce('client_health_check'); ?>'
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('action-result').innerHTML = '<p style="color: green;">Health check completed!</p>';
                document.getElementById('system-status').innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
            })
            .catch(error => {
                document.getElementById('action-result').innerHTML = '<p style="color: red;">Error: ' + error + '</p>';
            });
        }
        
        function flushCache() {
            document.getElementById('action-result').innerHTML = '<p>Flushing cache...</p>';
            fetch(ajaxurl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: 'action=client_cache_flush&nonce=' + '<?php echo wp_create_nonce('client_cache_flush'); ?>'
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('action-result').innerHTML = '<p style="color: green;">Cache flushed successfully!</p>';
            })
            .catch(error => {
                document.getElementById('action-result').innerHTML = '<p style="color: red;">Error: ' + error + '</p>';
            });
        }
        
        function createBackup() {
            document.getElementById('action-result').innerHTML = '<p>Creating backup...</p>';
            fetch(ajaxurl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: 'action=client_backup&nonce=' + '<?php echo wp_create_nonce('client_backup'); ?>'
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('action-result').innerHTML = '<p style="color: green;">Backup created successfully!</p>';
            })
            .catch(error => {
                document.getElementById('action-result').innerHTML = '<p style="color: red;">Error: ' + error + '</p>';
            });
        }
        </script>
        <?php
    }
    
    public function health_check() {
        check_ajax_referer('client_health_check', 'nonce');
        
        $status = array(
            'wordpress' => array(
                'version' => get_bloginfo('version'),
                'multisite' => is_multisite(),
                'memory_limit' => ini_get('memory_limit'),
            ),
            'php' => array(
                'version' => PHP_VERSION,
                'extensions' => get_loaded_extensions(),
            ),
            'database' => array(
                'version' => $GLOBALS['wpdb']->db_version(),
                'prefix' => $GLOBALS['wpdb']->prefix,
            ),
            'cache' => array(
                'redis_connected' => class_exists('Redis'),
                'object_cache' => wp_using_ext_object_cache(),
            ),
            'server' => array(
                'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
                'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? 'Unknown',
            )
        );
        
        wp_send_json_success($status);
    }
    
    public function flush_cache() {
        check_ajax_referer('client_cache_flush', 'nonce');
        
        // Flush WordPress caches
        wp_cache_flush();
        
        // Flush rewrite rules
        flush_rewrite_rules();
        
        wp_send_json_success('Cache flushed successfully');
    }
    
    public function create_backup() {
        check_ajax_referer('client_backup', 'nonce');
        
        // Create backup directory
        $backup_dir = WP_CONTENT_DIR . '/backups';
        if (!file_exists($backup_dir)) {
            wp_mkdir_p($backup_dir);
        }
        
        // Export database
        $backup_file = $backup_dir . '/backup-' . date('Y-m-d-H-i-s') . '.sql';
        $command = "mysqldump -h " . DB_HOST . " -u " . DB_USER . " -p" . DB_PASSWORD . " " . DB_NAME . " > " . $backup_file;
        exec($command, $output, $return_code);
        
        if ($return_code === 0) {
            wp_send_json_success('Backup created: ' . $backup_file);
        } else {
            wp_send_json_error('Backup failed');
        }
    }
}

// Initialize the client manager
new Client_Manager();
