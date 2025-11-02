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
    // Use realpath to ensure no directory traversal
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

