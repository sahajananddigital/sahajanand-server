<?php
/**
 * Helper functions for Web UI
 */

/**
 * Execute shell command and return output
 * 
 * @param string $command The command to execute (should already be escaped)
 * @param string|null $cwd Working directory (defaults to PROJECT_ROOT)
 * @return array ['success' => bool, 'output' => string, 'return_code' => int]
 */
function exec_command($command, $cwd = null) {
    // Validate command is not empty
    if (empty($command) || !is_string($command)) {
        return [
            'success' => false,
            'output' => 'Invalid command',
            'return_code' => 1
        ];
    }
    
    $cwd = $cwd ?? PROJECT_ROOT;
    $output = [];
    $return_var = 0;
    
    // Store current directory
    $original_cwd = getcwd();
    
    try {
        // Change to working directory if it exists and is accessible
        if (is_dir($cwd) && is_readable($cwd)) {
            chdir($cwd);
        } else {
            error_log("WebUI: Invalid working directory: $cwd");
            return [
                'success' => false,
                'output' => 'Invalid working directory',
                'return_code' => 1
            ];
        }
        
        // Execute command (command should already be properly escaped)
        exec($command . ' 2>&1', $output, $return_var);
        
        // Restore original directory
        if ($original_cwd !== false) {
            chdir($original_cwd);
        }
        
        return [
            'success' => $return_var === 0,
            'output' => implode("\n", $output),
            'return_code' => $return_var
        ];
    } catch (Exception $e) {
        // Restore original directory on error
        if ($original_cwd !== false) {
            @chdir($original_cwd);
        }
        error_log("WebUI: Command execution error: " . $e->getMessage());
        return [
            'success' => false,
            'output' => 'Command execution failed',
            'return_code' => 1
        ];
    }
}

/**
 * Get list of clients
 */
function get_clients() {
    $clients = [];
    $clients_dir = CLIENTS_DIR;
    
    if (!is_dir($clients_dir)) {
        return $clients;
    }
    
    $dirs = glob($clients_dir . '/*', GLOB_ONLYDIR);
    foreach ($dirs as $dir) {
        $client_name = basename($dir);
        $compose_file = $dir . '/docker-compose.yml';
        
        if (file_exists($compose_file)) {
            $clients[] = [
                'name' => $client_name,
                'path' => $dir,
                'compose_file' => $compose_file,
                'hostname' => extract_hostname($compose_file),
                'status' => get_container_status($client_name),
                'has_database_dir' => is_dir($dir . '/database')
            ];
        }
    }
    
    return $clients;
}

/**
 * Extract hostname from docker-compose.yml
 */
function extract_hostname($compose_file) {
    $content = file_get_contents($compose_file);
    if (preg_match('/Host\(`([^`]+)`\)/', $content, $matches)) {
        return $matches[1];
    }
    return null;
}

/**
 * Get Docker container status
 */
function get_container_status($container_name) {
    $result = exec_command("docker ps -a --filter name=^{$container_name}\$ --format '{{.Status}}|{{.State}}'");
    
    if (!$result['success']) {
        return 'unknown';
    }
    
    $output = trim($result['output']);
    if (empty($output)) {
        return 'not_found';
    }
    
    $parts = explode('|', $output);
    $state = $parts[1] ?? 'unknown';
    
    return $state === 'running' ? 'running' : 'stopped';
}

/**
 * Get MySQL databases for clients
 */
function get_client_databases() {
    $databases = [];
    $clients = get_clients();
    
    // Get MySQL root password
    $mysql_root_pass = get_mysql_root_password();
    
    foreach ($clients as $client) {
        $db_name = $client['name'] . '_db';
        // Escape database name for SQL query
        $db_name_escaped = str_replace(['\\', '"'], ['\\\\', '\\"'], $db_name);
        $result = exec_command("docker exec mysql mysql -u root -p" . escape_shell_arg($mysql_root_pass) . " -e 'SHOW DATABASES LIKE \\\"{$db_name_escaped}\\\";' 2>/dev/null");
        
        if ($result['success'] && strpos($result['output'], $db_name) !== false) {
            // Get database size
            $size_result = exec_command("docker exec mysql mysql -u root -p" . escape_shell_arg($mysql_root_pass) . " -e 'SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS \"DB Size in MB\" FROM information_schema.tables WHERE table_schema = \\\"{$db_name_escaped}\\\";' 2>/dev/null");
            $size = 0;
            if ($size_result['success']) {
                preg_match('/\d+\.?\d*/', $size_result['output'], $matches);
                $size = $matches[0] ?? 0;
            }
            
            $databases[] = [
                'name' => $db_name,
                'client' => $client['name'],
                'username' => $client['name'] . '_user',
                'size_mb' => floatval($size),
                'exists' => true
            ];
        }
    }
    
    return $databases;
}

/**
 * Get Docker containers
 */
function get_containers() {
    $result = exec_command("docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.State}}|{{.Ports}}'");
    
    if (!$result['success']) {
        return [];
    }
    
    $containers = [];
    $lines = explode("\n", trim($result['output']));
    
    foreach ($lines as $line) {
        if (empty(trim($line))) continue;
        
        $parts = explode('|', $line);
        $containers[] = [
            'name' => $parts[0] ?? '',
            'image' => $parts[1] ?? '',
            'status' => $parts[2] ?? '',
            'state' => $parts[3] ?? 'unknown',
            'ports' => $parts[4] ?? ''
        ];
    }
    
    return $containers;
}

/**
 * Get system information
 */
function get_system_info() {
    $info = [
        'docker_version' => '',
        'disk_usage' => [],
        'memory' => [],
        'php_version' => PHP_VERSION,
        'server_time' => date('Y-m-d H:i:s')
    ];
    
    // Docker version
    $docker_result = exec_command('docker --version');
    if ($docker_result['success']) {
        $info['docker_version'] = trim($docker_result['output']);
    }
    
    // Disk usage
    $df_result = exec_command('df -h /');
    if ($df_result['success']) {
        $info['disk_usage'] = $df_result['output'];
    }
    
    return $info;
}

/**
 * Get backup files
 */
function get_backups($client_name = null) {
    $backups = [];
    $backup_dir = BACKUP_DIR;
    
    if (!is_dir($backup_dir)) {
        return $backups;
    }
    
    // Normalize backup directory path
    $real_backup_dir = realpath($backup_dir);
    if (!$real_backup_dir) {
        return $backups;
    }
    
    if ($client_name) {
        // Validate client name to prevent path traversal
        if (!validate_client_name($client_name)) {
            return $backups;
        }
        $client_dir = $real_backup_dir . '/' . basename($client_name);
        $real_client_dir = realpath($client_dir);
        
        // Ensure we're still within backup directory
        if (!$real_client_dir || strpos($real_client_dir, $real_backup_dir) !== 0) {
            return $backups;
        }
        
        $files = glob($real_client_dir . '/*/*.zst');
    } else {
        $files = glob($real_backup_dir . '/*/*/*.zst');
    }
    
    foreach ($files as $file) {
        // Validate file path is within backup directory
        $real_file = realpath($file);
        if (!$real_file || strpos($real_file, $real_backup_dir) !== 0) {
            continue;
        }
        
        // Only process .zst files
        if (pathinfo($real_file, PATHINFO_EXTENSION) !== 'zst') {
            continue;
        }
        
        if (!is_file($real_file) || !is_readable($real_file)) {
            continue;
        }
        
        $path_info = pathinfo($real_file);
        $type = basename(dirname($real_file)); // 'database' or 'files'
        $client = basename(dirname(dirname($real_file))); // client name
        
        $backups[] = [
            'path' => $real_file,
            'filename' => $path_info['basename'],
            'client' => $client,
            'type' => $type,
            'size' => filesize($real_file),
            'modified' => filemtime($real_file),
            'date' => date('Y-m-d H:i:s', filemtime($real_file))
        ];
    }
    
    // Sort by date descending
    usort($backups, function($a, $b) {
        return $b['modified'] - $a['modified'];
    });
    
    return $backups;
}

/**
 * Format file size
 */
function format_size($bytes) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    $bytes /= pow(1024, $pow);
    return round($bytes, 2) . ' ' . $units[$pow];
}

