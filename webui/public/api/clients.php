<?php
/**
 * Clients API Endpoint
 */

header('Content-Type: application/json');
$isDocker = file_exists('/.dockerenv');
$includes_path = $isDocker ? '/var/www/webui/includes' : __DIR__ . '/../../includes';
require_once $includes_path . '/config.php';
require_once $includes_path . '/auth.php';
require_once $includes_path . '/functions.php';

// Require authentication
require_auth();

// Set security headers
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = sanitize_input($input['action'] ?? '');
    $name = sanitize_input($input['name'] ?? '');
    $csrf_token = $input['csrf_token'] ?? '';
    
    // Validate CSRF token
    if (!validate_csrf_token($csrf_token)) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Invalid security token']);
        exit;
    }
    
    // Validate client name
    if (empty($name) || !validate_client_name($name)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid client name']);
        exit;
    }
    
    // Prevent path traversal
    $name = basename($name);
    
    // Multi-tenant authorization check
    $user_client = get_user_client();
    if ($user_client !== null && $name !== $user_client) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Unauthorized client access']);
        exit;
    }
    
    // Handle Client Creation
    if ($action === 'create') {
        if (!is_admin()) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Forbidden: Administrator privileges required to deploy clients']);
            exit;
        }
        $template = sanitize_input($input['template'] ?? 'wordpress');
        $domain = sanitize_input($input['domain'] ?? '');
        $create_db = filter_var($input['create_db'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $db_password = $input['db_password'] ?? '';
        
        $allowed_templates = ['wordpress', 'erpnext', 'postiz'];
        if (!in_array($template, $allowed_templates)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Invalid template name']);
            exit;
        }
        
        if (empty($domain)) {
            $base_domain = get_env_var('BASE_DOMAIN', 'localhost');
            $domain = $name . '.' . $base_domain;
        }
        
        if (!preg_match('/^[a-zA-Z0-9.-]+$/', $domain)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Invalid domain format']);
            exit;
        }
        
        $target_dir = CLIENTS_DIR . '/' . $name;
        if (file_exists($target_dir)) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'A client directory with this name already exists']);
            exit;
        }
        
        $template_dir = CLIENTS_DIR . '/' . $template;
        if (!file_exists($template_dir) || !is_dir($template_dir)) {
            http_response_code(404);
            echo json_encode(['success' => false, 'message' => 'Template directory not found']);
            exit;
        }
        
        if (!mkdir($target_dir, 0755, true)) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Failed to create client directory']);
            exit;
        }
        
        // Copy directory helper
        $copy_dir = function($src, $dst) use (&$copy_dir) {
            $dir = opendir($src);
            @mkdir($dst, 0755, true);
            while (($file = readdir($dir)) !== false) {
                if ($file === '.' || $file === '..') {
                    continue;
                }
                if (is_dir($src . '/' . $file)) {
                    $copy_dir($src . '/' . $file, $dst . '/' . $file);
                } else {
                    copy($src . '/' . $file, $dst . '/' . $file);
                }
            }
            closedir($dir);
        };
        
        $copy_dir($template_dir, $target_dir);
        
        if (file_exists($target_dir . '/supervisord.log')) {
            @unlink($target_dir . '/supervisord.log');
        }
        
        $compose_file = $target_dir . '/docker-compose.yml';
        if (file_exists($compose_file)) {
            $content = file_get_contents($compose_file);
            
            $template_domain = $template . '.example.com';
            $content = str_replace($template_domain, $domain, $content);
            $content = str_replace($template, $name, $content);
            
            if ($template === 'postiz') {
                if (empty($db_password)) {
                    $db_password = bin2hex(random_bytes(10));
                }
                $content = str_replace('postiz_secure_password', $db_password, $content);
            }
            
            if ($template === 'erpnext') {
                if (empty($db_password)) {
                    $db_password = bin2hex(random_bytes(10));
                }
                $content = str_replace('erpnext_password', $db_password, $content);
            }
            
            file_put_contents($compose_file, $content);
        }
        
        if ($create_db) {
            $db_dir = $target_dir . '/database';
            if (!is_dir($db_dir)) {
                @mkdir($db_dir, 0775, true);
            }
            $db_path = $db_dir . '/' . $name . '.db';
            try {
                $db = new PDO('sqlite:' . $db_path);
                $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
                $db->exec("CREATE TABLE IF NOT EXISTS _metadata (key TEXT PRIMARY KEY, value TEXT)");
                $db->exec("INSERT OR IGNORE INTO _metadata (key, value) VALUES ('created_at', '" . date('Y-m-d H:i:s') . "')");
                $db = null; // Close connection
                @chmod($db_path, 0666);
                @chmod($db_dir, 0777);
            } catch (PDOException $e) {
                error_log("WebUI: Failed to initialize SQLite DB at client deploy: " . $e->getMessage());
            }
        }
        
        $result = exec_command("cd " . escape_shell_arg($target_dir) . " && docker-compose up -d --build");
        
        echo json_encode([
            'success' => $result['success'],
            'message' => $result['success'] ? 'Client created and started successfully' : 'Client files initialized, but container build failed'
        ]);
        exit;
    }
    
    // For start/stop/restart operations, locate client
    $client_dir = CLIENTS_DIR . '/' . $name;
    $real_client_dir = realpath($client_dir);
    if (!$real_client_dir || strpos($real_client_dir, realpath(CLIENTS_DIR)) !== 0) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Invalid client path']);
        exit;
    }
    $compose_file = $real_client_dir . '/docker-compose.yml';
    
    if (!file_exists($compose_file)) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Client not found']);
        exit;
    }
    
    // Validate action
    $allowed_actions = ['start', 'stop', 'restart'];
    if (!in_array($action, $allowed_actions)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        exit;
    }
    
    switch ($action) {
        case 'start':
            $result = exec_command("cd " . escape_shell_arg($real_client_dir) . " && docker-compose up -d");
            echo json_encode([
                'success' => $result['success'],
                'message' => $result['success'] ? 'Client started successfully' : 'Failed to start client. Check container logs for details.'
            ]);
            break;
            
        case 'stop':
            $result = exec_command("cd " . escape_shell_arg($real_client_dir) . " && docker-compose down");
            echo json_encode([
                'success' => $result['success'],
                'message' => $result['success'] ? 'Client stopped successfully' : 'Failed to stop client. Check container logs for details.'
            ]);
            break;
            
        case 'restart':
            $result = exec_command("cd " . escape_shell_arg($real_client_dir) . " && docker-compose restart");
            echo json_encode([
                'success' => $result['success'],
                'message' => $result['success'] ? 'Client restarted successfully' : 'Failed to restart client. Check container logs for details.'
            ]);
            break;
            
        default:
            echo json_encode(['success' => false, 'message' => 'Invalid action']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
}


