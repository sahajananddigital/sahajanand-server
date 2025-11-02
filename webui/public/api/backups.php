<?php
/**
 * Backups API Endpoint
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

if ($method === 'GET' && isset($_GET['action']) && $_GET['action'] === 'download') {
    $path = $_GET['path'] ?? '';
    
    if (empty($path)) {
        http_response_code(400);
        echo 'Invalid request';
        exit;
    }
    
    // Sanitize and validate path
    $path = htmlspecialchars(strip_tags($path), ENT_QUOTES, 'UTF-8');
    
    if (!file_exists($path)) {
        http_response_code(404);
        echo 'File not found';
        exit;
    }
    
    // Security check - ensure path is within backup directory
    $real_path = realpath($path);
    $real_backup_dir = realpath(BACKUP_DIR);
    
    if (!$real_path || !$real_backup_dir || strpos($real_path, $real_backup_dir) !== 0) {
        http_response_code(403);
        echo 'Access denied';
        exit;
    }
    
    // Additional check - must be a .zst file
    if (pathinfo($real_path, PATHINFO_EXTENSION) !== 'zst') {
        http_response_code(403);
        echo 'Invalid file type';
        exit;
    }
    
    header('Content-Type: application/octet-stream');
    header('Content-Disposition: attachment; filename="' . basename($path) . '"');
    header('Content-Length: ' . filesize($path));
    readfile($path);
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
    
    switch ($action) {
        case 'create':
            $client = sanitize_input($input['client'] ?? '');
            $type = sanitize_input($input['type'] ?? 'all');
            
            if (empty($client) || !validate_client_name($client)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid client name']);
                exit;
            }
            
            // Validate type
            $allowed_types = ['all', 'database', 'files'];
            if (!in_array($type, $allowed_types)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid backup type']);
                exit;
            }
            
            // Check if backup script exists and is executable
            if (!file_exists(BACKUP_SCRIPT)) {
                http_response_code(500);
                echo json_encode(['success' => false, 'message' => 'Backup script not found']);
                exit;
            }
            
            if (!is_executable(BACKUP_SCRIPT)) {
                http_response_code(500);
                echo json_encode(['success' => false, 'message' => 'Backup script is not executable']);
                exit;
            }
            
            // Use proper escaping and redirect output
            $cmd = "nohup " . escape_shell_arg(BACKUP_SCRIPT);
            if (!empty($client)) {
                // Note: Backup script doesn't support single client yet, but structure is ready
                $cmd .= " > /tmp/backup_" . time() . ".log 2>&1 &";
            } else {
                $cmd .= " > /tmp/backup_" . time() . ".log 2>&1 &";
            }
            
            // Execute in background
            if (function_exists('exec')) {
                exec($cmd, $output, $return_code);
                if ($return_code !== 0) {
                    http_response_code(500);
                    echo json_encode(['success' => false, 'message' => 'Failed to start backup process']);
                    exit;
                }
            } else {
                http_response_code(500);
                echo json_encode(['success' => false, 'message' => 'exec() function is disabled']);
                exit;
            }
            
            echo json_encode([
                'success' => true,
                'message' => 'Backup started in background. This may take a few minutes.'
            ]);
            break;
            
        case 'restore':
            $client = sanitize_input($input['client'] ?? '');
            $path = $input['path'] ?? '';
            $type = sanitize_input($input['type'] ?? '');
            
            if (empty($client) || empty($path)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Client name and backup path are required']);
                exit;
            }
            
            if (!validate_client_name($client)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Invalid client name']);
                exit;
            }
            
            // Security check - validate path
            $path = htmlspecialchars(strip_tags($path), ENT_QUOTES, 'UTF-8');
            $real_path = realpath($path);
            $real_backup_dir = realpath(BACKUP_DIR);
            
            if (!$real_path || !$real_backup_dir || strpos($real_path, $real_backup_dir) !== 0) {
                http_response_code(403);
                echo json_encode(['success' => false, 'message' => 'Invalid backup path']);
                exit;
            }
            
            // Must be a .zst file
            if (pathinfo($real_path, PATHINFO_EXTENSION) !== 'zst') {
                http_response_code(403);
                echo json_encode(['success' => false, 'message' => 'Invalid file type']);
                exit;
            }
            
            // Decompress if needed
            $decompressed_path = $path;
            if (pathinfo($path, PATHINFO_EXTENSION) === 'zst') {
                $decompressed_path = str_replace('.zst', '', $path);
                $result = exec_command("zstd -d -f " . escapeshellarg($path));
                if (!$result['success']) {
                    echo json_encode(['success' => false, 'message' => 'Failed to decompress backup']);
                    exit;
                }
            }
            
            // Restore based on type
            if ($type === 'database' || strpos($decompressed_path, 'db') !== false || strpos(basename($path), 'db') !== false) {
                // Restore MySQL database
                $db_name = $client . '_db';
                
                // Validate decompressed file exists
                if (!file_exists($decompressed_path)) {
                    http_response_code(400);
                    echo json_encode(['success' => false, 'message' => 'Decompressed backup file not found']);
                    exit;
                }
                
                // Load MySQL root password
                $mysql_root_pass = get_mysql_root_password();
                
                // Validate file is a SQL file
                if (pathinfo($decompressed_path, PATHINFO_EXTENSION) !== 'sql') {
                    http_response_code(400);
                    echo json_encode(['success' => false, 'message' => 'Invalid backup file type']);
                    exit;
                }
                
                $result = exec_command("docker exec -i mysql mysql -u root -p" . escape_shell_arg($mysql_root_pass) . " < " . escape_shell_arg($decompressed_path) . " 2>&1");
                echo json_encode([
                    'success' => $result['success'],
                    'message' => $result['success'] ? 'Database restored successfully' : 'Failed to restore database. Check MySQL logs for details.'
                ]);
            } else {
                // Restore files
                $client_dir = CLIENTS_DIR . '/' . $client;
                // Validate client directory exists
                $real_client_dir = realpath($client_dir);
                if (!$real_client_dir || strpos($real_client_dir, realpath(CLIENTS_DIR)) !== 0) {
                    http_response_code(403);
                    echo json_encode(['success' => false, 'message' => 'Invalid client directory']);
                    exit;
                }
                
                // Validate file is a tar file
                if (!in_array(pathinfo($decompressed_path, PATHINFO_EXTENSION), ['tar', 'gz'])) {
                    http_response_code(400);
                    echo json_encode(['success' => false, 'message' => 'Invalid backup file type']);
                    exit;
                }
                
                if (!file_exists($decompressed_path)) {
                    http_response_code(400);
                    echo json_encode(['success' => false, 'message' => 'Decompressed backup file not found']);
                    exit;
                }
                
                $result = exec_command("tar -xf " . escape_shell_arg($decompressed_path) . " -C " . escape_shell_arg($real_client_dir) . " --strip-components=1 2>&1");
                echo json_encode([
                    'success' => $result['success'],
                    'message' => $result['success'] ? 'Files restored successfully' : 'Failed to restore files. Check file permissions and disk space.'
                ]);
            }
            break;
            
        case 'delete':
            $path = $input['path'] ?? '';
            
            if (empty($path)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'Backup path is required']);
                exit;
            }
            
            // Security check - validate path
            $path = htmlspecialchars(strip_tags($path), ENT_QUOTES, 'UTF-8');
            $real_path = realpath($path);
            $real_backup_dir = realpath(BACKUP_DIR);
            
            if (!$real_path || !$real_backup_dir || strpos($real_path, $real_backup_dir) !== 0) {
                http_response_code(403);
                echo json_encode(['success' => false, 'message' => 'Invalid backup path']);
                exit;
            }
            
            // Must be a .zst file
            if (pathinfo($real_path, PATHINFO_EXTENSION) !== 'zst') {
                http_response_code(403);
                echo json_encode(['success' => false, 'message' => 'Invalid file type']);
                exit;
            }
            
            if (unlink($path)) {
                echo json_encode(['success' => true, 'message' => 'Backup deleted successfully']);
            } else {
                echo json_encode(['success' => false, 'message' => 'Failed to delete backup']);
            }
            break;
            
        default:
            echo json_encode(['success' => false, 'message' => 'Invalid action']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
}

