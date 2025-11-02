<?php
/**
 * Databases API Endpoint
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
    $csrf_token = $input['csrf_token'] ?? '';
    
    // Validate CSRF token
    if (!validate_csrf_token($csrf_token)) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Invalid security token']);
        exit;
    }
    
    switch ($action) {
        case 'create':
            $client = sanitize_input($input['client'] ?? '');
            $password = $input['password'] ?? ''; // Don't sanitize password, will be escaped in command
            
            if (empty($client) || !validate_client_name($client)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid client name']);
                exit;
            }
            
            // Prevent path traversal
            $client = basename($client);
            $script = MYSQL_DIR . '/add-client-db.sh';
            if (!file_exists($script)) {
                http_response_code(404);
                echo json_encode(['success' => false, 'message' => 'Database creation script not found']);
                exit;
            }
            
            $cmd = "bash " . escape_shell_arg($script) . " " . escape_shell_arg($client);
            if (!empty($password)) {
                // Validate password (alphanumeric and special chars, max 100 chars)
                if (strlen($password) > 100 || !preg_match('/^[a-zA-Z0-9@#$%^&*()_+\-=\[\]{};\':"\\|,.<>\/?~`]+$/', $password)) {
                    http_response_code(400);
                    echo json_encode(['success' => false, 'message' => 'Invalid password format']);
                    exit;
                }
                $cmd .= " " . escape_shell_arg($password);
            }
            
            $result = exec_command($cmd, PROJECT_ROOT);
            echo json_encode([
                'success' => $result['success'],
                'message' => $result['success'] ? 'Database created successfully' : 'Failed to create database'
            ]);
            break;
            
        case 'delete':
            $name = sanitize_input($input['name'] ?? '');
            $client_name = sanitize_input($input['client'] ?? '');
            
            if (empty($name) || empty($client_name)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Database name and client are required']);
                exit;
            }
            
            // Validate database name format (should be clientname_db)
            if (!preg_match('/^[a-zA-Z0-9_]+$/', $name) || !validate_client_name($client_name)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid database or client name']);
                exit;
            }
            
            // Load MySQL root password
            $mysql_root_pass = get_mysql_root_password();
            
            // Escape database and username for SQL (already validated, but be extra safe)
            // Use backticks for database name and quotes for username
            $db_name_sql = '`' . str_replace('`', '``', $name) . '`';
            $user_name_sql = "'" . str_replace("'", "''", $client_name . '_user') . "'";
            $sql = "DROP DATABASE IF EXISTS {$db_name_sql}; DROP USER IF EXISTS {$user_name_sql}@'%';";
            $result = exec_command("docker exec mysql mysql -u root -p" . escape_shell_arg($mysql_root_pass) . " -e " . escape_shell_arg($sql));
            
            echo json_encode([
                'success' => $result['success'],
                'message' => $result['success'] ? 'Database deleted successfully' : 'Failed to delete database'
            ]);
            break;
            
        default:
            echo json_encode(['success' => false, 'message' => 'Invalid action']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
}

