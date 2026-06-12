<?php
/**
 * System API Endpoint
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

if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'logs') {
    $container = sanitize_input($_GET['container'] ?? '');
    
    if (empty($container) || !validate_container_name($container)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid container name']);
        exit;
    }
    
    // Multi-tenant check
    $user_client = get_user_client();
    if ($user_client !== null && strpos($container, $user_client) === false) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Unauthorized container logs access']);
        exit;
    }
    
    // Limit log lines and escape container name
    $result = exec_command("docker logs --tail 100 " . escape_shell_arg($container) . " 2>&1");
    echo json_encode([
        'success' => true,
        'logs' => htmlspecialchars($result['output'], ENT_QUOTES, 'UTF-8')
    ]);
    exit;
}

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
    
    // User Management actions (Admin only)
    if ($action === 'create_user' || $action === 'delete_user') {
        if (!is_admin()) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Forbidden: Administrator privileges required']);
            exit;
        }
        
        $db = get_db();
        if (!$db) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Database connection failed']);
            exit;
        }
        
        if ($action === 'create_user') {
            $username = sanitize_input($input['username'] ?? '');
            $password = $input['password'] ?? '';
            $role = sanitize_input($input['role'] ?? 'client');
            $client_name = sanitize_input($input['client_name'] ?? null);
            
            if (empty($username) || empty($password)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Username and password are required']);
                exit;
            }
            
            if (!preg_match('/^[a-zA-Z0-9_-]+$/', $username) || strlen($username) > 50) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid username format']);
                exit;
            }
            
            $password_hash = password_hash($password, PASSWORD_BCRYPT);
            
            try {
                $stmt = $db->prepare("INSERT INTO users (username, password_hash, role, client_name) VALUES (?, ?, ?, ?)");
                $stmt->execute([$username, $password_hash, $role, empty($client_name) ? null : $client_name]);
                echo json_encode(['success' => true, 'message' => 'User created successfully']);
            } catch (PDOException $e) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Failed to create user: ' . (strpos($e->getMessage(), 'UNIQUE') !== false ? 'Username already exists' : 'Database error')]);
            }
            exit;
        }
        
        if ($action === 'delete_user') {
            $id = filter_var($input['id'] ?? null, FILTER_VALIDATE_INT);
            if ($id === false || $id === null) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid user ID']);
                exit;
            }
            
            try {
                $stmt = $db->prepare("SELECT username FROM users WHERE id = ?");
                $stmt->execute([$id]);
                $username = $stmt->fetchColumn();
                
                if ($username === $_SESSION['user']) {
                    http_response_code(400);
                    echo json_encode(['success' => false, 'message' => 'Cannot delete currently logged in user']);
                    exit;
                }
                
                $stmt = $db->prepare("DELETE FROM users WHERE id = ?");
                $stmt->execute([$id]);
                echo json_encode(['success' => true, 'message' => 'User deleted successfully']);
            } catch (PDOException $e) {
                http_response_code(500);
                echo json_encode(['success' => false, 'message' => 'Database error occurred']);
            }
            exit;
        }
    }
    
    // Container Actions
    $container = sanitize_input($input['container'] ?? '');
    if (empty($container) || !validate_container_name($container)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid container name']);
        exit;
    }
    
    // Multi-tenant check
    $user_client = get_user_client();
    if ($user_client !== null && strpos($container, $user_client) === false) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Unauthorized container access']);
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
            $result = exec_command("docker start " . escape_shell_arg($container));
            echo json_encode([
                'success' => $result['success'],
                'message' => $result['success'] ? 'Container started successfully' : 'Failed to start container'
            ]);
            break;
            
        case 'stop':
            $result = exec_command("docker stop " . escape_shell_arg($container));
            echo json_encode([
                'success' => $result['success'],
                'message' => $result['success'] ? 'Container stopped successfully' : 'Failed to stop container'
            ]);
            break;
            
        case 'restart':
            $result = exec_command("docker restart " . escape_shell_arg($container));
            echo json_encode([
                'success' => $result['success'],
                'message' => $result['success'] ? 'Container restarted successfully' : 'Failed to restart container'
            ]);
            break;
            
        default:
            echo json_encode(['success' => false, 'message' => 'Invalid action']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
}
