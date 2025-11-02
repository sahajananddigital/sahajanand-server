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
    $container = sanitize_input($input['container'] ?? '');
    $csrf_token = $input['csrf_token'] ?? '';
    
    // Validate CSRF token
    if (!validate_csrf_token($csrf_token)) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Invalid security token']);
        exit;
    }
    
    if (empty($container) || !validate_container_name($container)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid container name']);
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

