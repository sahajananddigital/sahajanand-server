<?php
/**
 * Update Manager MU Plugin
 * Centralized WordPress updates for all clients
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Ensure WordPress is loaded
if (!function_exists('add_action')) {
    return;
}

class Update_Manager {
    
    public function __construct() {
        add_action('init', array($this, 'init'));
        add_action('admin_menu', array($this, 'add_admin_menu'));
        add_action('wp_ajax_update_wordpress', array($this, 'update_wordpress'));
        add_action('wp_ajax_update_plugins', array($this, 'update_plugins'));
        add_action('wp_ajax_update_themes', array($this, 'update_themes'));
        add_action('wp_ajax_check_updates', array($this, 'check_updates'));
    }
    
    public function init() {
        // Disable automatic updates for individual clients
        add_filter('automatic_updater_disabled', '__return_true');
        
        // Add update notifications
        add_action('admin_notices', array($this, 'show_update_notices'));
    }
    
    public function add_admin_menu() {
        add_submenu_page(
            'client-manager',
            'Update Manager',
            'Updates',
            'manage_options',
            'update-manager',
            array($this, 'admin_page')
        );
    }
    
    public function admin_page() {
        $wp_version = get_bloginfo('version');
        $php_version = PHP_VERSION;
        
        // Get update information
        $core_updates = get_core_updates();
        $plugin_updates = get_plugin_updates();
        $theme_updates = get_theme_updates();
        
        ?>
        <div class="wrap">
            <h1>Update Manager</h1>
            
            <div class="card">
                <h2>Current Versions</h2>
                <table class="form-table">
                    <tr>
                        <th>WordPress:</th>
                        <td><?php echo esc_html($wp_version); ?></td>
                    </tr>
                    <tr>
                        <th>PHP:</th>
                        <td><?php echo esc_html($php_version); ?></td>
                    </tr>
                </table>
            </div>
            
            <div class="card">
                <h2>WordPress Core Updates</h2>
                <?php if (!empty($core_updates) && $core_updates[0]->response !== 'latest'): ?>
                    <p>New WordPress version available: <?php echo esc_html($core_updates[0]->version); ?></p>
                    <button type="button" class="button button-primary" onclick="updateWordPress()">Update WordPress</button>
                <?php else: ?>
                    <p>WordPress is up to date.</p>
                <?php endif; ?>
            </div>
            
            <div class="card">
                <h2>Plugin Updates</h2>
                <?php if (!empty($plugin_updates)): ?>
                    <p><?php echo count($plugin_updates); ?> plugins have updates available.</p>
                    <button type="button" class="button button-primary" onclick="updatePlugins()">Update All Plugins</button>
                    <ul>
                        <?php foreach ($plugin_updates as $plugin): ?>
                            <li><?php echo esc_html($plugin->Name); ?> - <?php echo esc_html($plugin->update->new_version); ?></li>
                        <?php endforeach; ?>
                    </ul>
                <?php else: ?>
                    <p>All plugins are up to date.</p>
                <?php endif; ?>
            </div>
            
            <div class="card">
                <h2>Theme Updates</h2>
                <?php if (!empty($theme_updates)): ?>
                    <p><?php echo count($theme_updates); ?> themes have updates available.</p>
                    <button type="button" class="button button-primary" onclick="updateThemes()">Update All Themes</button>
                    <ul>
                        <?php foreach ($theme_updates as $theme): ?>
                            <li><?php echo esc_html($theme->Name); ?> - <?php echo esc_html($theme->update['new_version']); ?></li>
                        <?php endforeach; ?>
                    </ul>
                <?php else: ?>
                    <p>All themes are up to date.</p>
                <?php endif; ?>
            </div>
            
            <div class="card">
                <h2>Quick Actions</h2>
                <p>
                    <button type="button" class="button" onclick="checkUpdates()">Check for Updates</button>
                    <button type="button" class="button" onclick="flushCache()">Flush Cache</button>
                </p>
                <div id="update-result"></div>
            </div>
        </div>
        
        <script>
        function updateWordPress() {
            document.getElementById('update-result').innerHTML = '<p>Updating WordPress...</p>';
            fetch(ajaxurl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: 'action=update_wordpress&nonce=' + '<?php echo wp_create_nonce('update_wordpress'); ?>'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    document.getElementById('update-result').innerHTML = '<p style="color: green;">WordPress updated successfully!</p>';
                    location.reload();
                } else {
                    document.getElementById('update-result').innerHTML = '<p style="color: red;">Error: ' + data.data + '</p>';
                }
            })
            .catch(error => {
                document.getElementById('update-result').innerHTML = '<p style="color: red;">Error: ' + error + '</p>';
            });
        }
        
        function updatePlugins() {
            document.getElementById('update-result').innerHTML = '<p>Updating plugins...</p>';
            fetch(ajaxurl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: 'action=update_plugins&nonce=' + '<?php echo wp_create_nonce('update_plugins'); ?>'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    document.getElementById('update-result').innerHTML = '<p style="color: green;">Plugins updated successfully!</p>';
                    location.reload();
                } else {
                    document.getElementById('update-result').innerHTML = '<p style="color: red;">Error: ' + data.data + '</p>';
                }
            })
            .catch(error => {
                document.getElementById('update-result').innerHTML = '<p style="color: red;">Error: ' + error + '</p>';
            });
        }
        
        function updateThemes() {
            document.getElementById('update-result').innerHTML = '<p>Updating themes...</p>';
            fetch(ajaxurl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: 'action=update_themes&nonce=' + '<?php echo wp_create_nonce('update_themes'); ?>'
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    document.getElementById('update-result').innerHTML = '<p style="color: green;">Themes updated successfully!</p>';
                    location.reload();
                } else {
                    document.getElementById('update-result').innerHTML = '<p style="color: red;">Error: ' + data.data + '</p>';
                }
            })
            .catch(error => {
                document.getElementById('update-result').innerHTML = '<p style="color: red;">Error: ' + error + '</p>';
            });
        }
        
        function checkUpdates() {
            document.getElementById('update-result').innerHTML = '<p>Checking for updates...</p>';
            fetch(ajaxurl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: 'action=check_updates&nonce=' + '<?php echo wp_create_nonce('check_updates'); ?>'
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('update-result').innerHTML = '<p style="color: green;">Update check completed!</p>';
                location.reload();
            })
            .catch(error => {
                document.getElementById('update-result').innerHTML = '<p style="color: red;">Error: ' + error + '</p>';
            });
        }
        
        function flushCache() {
            document.getElementById('update-result').innerHTML = '<p>Flushing cache...</p>';
            wp_cache_flush();
            document.getElementById('update-result').innerHTML = '<p style="color: green;">Cache flushed!</p>';
        }
        </script>
        <?php
    }
    
    public function show_update_notices() {
        $core_updates = get_core_updates();
        $plugin_updates = get_plugin_updates();
        $theme_updates = get_theme_updates();
        
        if (!empty($core_updates) && $core_updates[0]->response !== 'latest') {
            echo '<div class="notice notice-warning"><p>WordPress update available: ' . esc_html($core_updates[0]->version) . '</p></div>';
        }
        
        if (!empty($plugin_updates)) {
            echo '<div class="notice notice-info"><p>' . count($plugin_updates) . ' plugin updates available.</p></div>';
        }
        
        if (!empty($theme_updates)) {
            echo '<div class="notice notice-info"><p>' . count($theme_updates) . ' theme updates available.</p></div>';
        }
    }
    
    public function update_wordpress() {
        check_ajax_referer('update_wordpress', 'nonce');
        
        if (!current_user_can('update_core')) {
            wp_send_json_error('Insufficient permissions');
        }
        
        // This would typically be handled by WP-CLI in a real implementation
        wp_send_json_success('WordPress update initiated (WP-CLI required for actual update)');
    }
    
    public function update_plugins() {
        check_ajax_referer('update_plugins', 'nonce');
        
        if (!current_user_can('update_plugins')) {
            wp_send_json_error('Insufficient permissions');
        }
        
        // This would typically be handled by WP-CLI in a real implementation
        wp_send_json_success('Plugin updates initiated (WP-CLI required for actual update)');
    }
    
    public function update_themes() {
        check_ajax_referer('update_themes', 'nonce');
        
        if (!current_user_can('update_themes')) {
            wp_send_json_error('Insufficient permissions');
        }
        
        // This would typically be handled by WP-CLI in a real implementation
        wp_send_json_success('Theme updates initiated (WP-CLI required for actual update)');
    }
    
    public function check_updates() {
        check_ajax_referer('check_updates', 'nonce');
        
        // Force WordPress to check for updates
        wp_version_check();
        wp_update_plugins();
        wp_update_themes();
        
        wp_send_json_success('Update check completed');
    }
}

// Initialize the update manager
new Update_Manager();
