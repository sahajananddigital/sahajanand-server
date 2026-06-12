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
    
    // Require admin access for database operations
    if (!is_admin()) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Forbidden: Administrator privileges required']);
        exit;
    }
    
    switch ($action) {
        case 'create':
            $client = sanitize_input($input['client'] ?? '');
            
            if (empty($client) || !validate_client_name($client)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid client name']);
                exit;
            }
            
            // Prevent path traversal
            $client = basename($client);
            $client_dir = CLIENTS_DIR . '/' . $client;
            
            if (!file_exists($client_dir) || !is_dir($client_dir)) {
                http_response_code(404);
                echo json_encode(['success' => false, 'message' => 'Client directory not found']);
                exit;
            }
            
            $db_dir = $client_dir . '/database';
            if (!is_dir($db_dir)) {
                if (!mkdir($db_dir, 0775, true)) {
                    http_response_code(500);
                    echo json_encode(['success' => false, 'message' => 'Failed to create database directory']);
                    exit;
                }
            }
            
            $db_name = $client . '.db';
            $db_path = $db_dir . '/' . $db_name;
            
            if (file_exists($db_path)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Database file already exists']);
                exit;
            }
            
            try {
                $db = new PDO('sqlite:' . $db_path);
                $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
                $db->exec("CREATE TABLE IF NOT EXISTS _metadata (key TEXT PRIMARY KEY, value TEXT)");
                $db->exec("INSERT OR IGNORE INTO _metadata (key, value) VALUES ('created_at', '" . date('Y-m-d H:i:s') . "')");
                $db = null; // Close connection
                
                @chmod($db_path, 0666);
                @chmod($db_dir, 0777);
                
                echo json_encode(['success' => true, 'message' => 'SQLite database created successfully']);
            } catch (PDOException $e) {
                http_response_code(500);
                echo json_encode(['success' => false, 'message' => 'Failed to initialize SQLite database: ' . $e->getMessage()]);
            }
            break;
            
        case 'delete':
            $name = sanitize_input($input['name'] ?? '');
            $client_name = sanitize_input($input['client'] ?? '');
            
            if (empty($name) || empty($client_name)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Database name and client are required']);
                exit;
            }
            
            if (!validate_client_name($client_name) || !preg_match('/^[a-zA-Z0-9._-]+$/', $name)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid database or client name']);
                exit;
            }
            
            $client_name = basename($client_name);
            $name = basename($name);
            
            $db_path = CLIENTS_DIR . '/' . $client_name . '/database/' . $name;
            $real_db_path = realpath($db_path);
            $real_clients_dir = realpath(CLIENTS_DIR);
            
            if (!$real_db_path || strpos($real_db_path, $real_clients_dir) !== 0 || !is_file($real_db_path)) {
                http_response_code(403);
                echo json_encode(['success' => false, 'message' => 'Invalid database path or file not found']);
                exit;
            }
            
            if (unlink($real_db_path)) {
                echo json_encode(['success' => true, 'message' => 'SQLite database deleted successfully']);
            } else {
                http_response_code(500);
                echo json_encode(['success' => false, 'message' => 'Failed to delete database file']);
            }
            break;
            
        default:
            echo json_encode(['success' => false, 'message' => 'Invalid action']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
}

