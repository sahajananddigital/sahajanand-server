<?php
/**
 * Authentication and Security System
 */

// Start secure session
if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.cookie_httponly', 1);
    ini_set('session.cookie_secure', isset($_SERVER['HTTPS']));
    ini_set('session.use_strict_mode', 1);
    ini_set('session.cookie_samesite', 'Strict');
    session_start();
}

// Regenerate session ID periodically to prevent fixation
if (!isset($_SESSION['created'])) {
    $_SESSION['created'] = time();
} elseif (time() - $_SESSION['created'] > 1800) {
    session_regenerate_id(true);
    $_SESSION['created'] = time();
}

// CSRF token generation and validation
function generate_csrf_token() {
    if (!isset($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function validate_csrf_token($token) {
    return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

// Connect to SQLite Database and ensure tables exist
function get_db() {
    static $db = null;
    if ($db !== null) {
        return $db;
    }
    
    $db_file = DB_FILE;
    $db_dir = dirname($db_file);
    if (!is_dir($db_dir)) {
        @mkdir($db_dir, 0755, true);
    }
    
    try {
        $db = new PDO('sqlite:' . $db_file);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        // Create tables
        $db->exec("CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password_hash TEXT,
            role TEXT,
            client_name TEXT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )");
        
        // Seed default user if empty
        $stmt = $db->query("SELECT COUNT(*) FROM users");
        $count = $stmt->fetchColumn();
        if ($count == 0) {
            $default_user = 'admin';
            $default_hash = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'; // admin123
            
            $auth_file = PROJECT_ROOT . '/.webui_auth';
            if (file_exists($auth_file)) {
                $lines = file($auth_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
                $plaintext_pass = '';
                foreach ($lines as $line) {
                    if (strpos($line, 'WEBUI_USERNAME=') === 0) {
                        $default_user = trim(substr($line, 15));
                    } elseif (strpos($line, 'WEBUI_PASSWORD_HASH=') === 0) {
                        $default_hash = trim(substr($line, 20));
                    } elseif (strpos($line, 'WEBUI_PASSWORD=') === 0) {
                        $plaintext_pass = trim(substr($line, 15));
                    }
                }
                if (!empty($plaintext_pass) && empty($default_hash)) {
                    $default_hash = password_hash($plaintext_pass, PASSWORD_DEFAULT);
                }
            } else {
                // Try .env
                $env_file = PROJECT_ROOT . '/.env';
                if (file_exists($env_file)) {
                    $lines = file($env_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
                    $plaintext_pass = '';
                    foreach ($lines as $line) {
                        if (strpos($line, 'WEBUI_USERNAME=') === 0) {
                            $default_user = trim(substr($line, 15));
                        } elseif (strpos($line, 'WEBUI_PASSWORD_HASH=') === 0) {
                            $default_hash = trim(substr($line, 20));
                        } elseif (strpos($line, 'WEBUI_PASSWORD=') === 0) {
                            $plaintext_pass = trim(substr($line, 15));
                        }
                    }
                    if (!empty($plaintext_pass) && empty($default_hash)) {
                        $default_hash = password_hash($plaintext_pass, PASSWORD_DEFAULT);
                    }
                }
            }
            
            $stmt = $db->prepare("INSERT INTO users (username, password_hash, role) VALUES (?, ?, 'admin')");
            $stmt->execute([$default_user, $default_hash]);
        }
    } catch (PDOException $e) {
        error_log("WebUI: SQLite authentication DB initialization failed: " . $e->getMessage());
        return null;
    }
    
    return $db;
}

// Check if user is authenticated
function is_authenticated() {
    return isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true && 
           isset($_SESSION['user']) && 
           isset($_SESSION['ip']) && $_SESSION['ip'] === $_SERVER['REMOTE_ADDR'];
}

// Check if user is administrator
function is_admin() {
    return is_authenticated() && isset($_SESSION['role']) && $_SESSION['role'] === 'admin';
}

// Get client name linked to user (returns null for admins)
function get_user_client() {
    return is_authenticated() ? ($_SESSION['client_name'] ?? null) : null;
}

// Login function
function login($username, $password) {
    $db = get_db();
    if (!$db) {
        return ['success' => false, 'message' => 'Database connection failed.'];
    }
    
    // Rate limiting - check failed attempts
    $attempts_file = sys_get_temp_dir() . '/webui_login_attempts_' . $_SERVER['REMOTE_ADDR'];
    $attempts = 0;
    $last_attempt = 0;
    
    if (file_exists($attempts_file)) {
        $data = json_decode(file_get_contents($attempts_file), true);
        $attempts = $data['attempts'] ?? 0;
        $last_attempt = $data['last_attempt'] ?? 0;
        
        // Reset after 15 minutes
        if (time() - $last_attempt > 900) {
            $attempts = 0;
        }
    }
    
    // Block after 5 failed attempts
    if ($attempts >= 5) {
        return ['success' => false, 'message' => 'Too many failed login attempts. Please try again in 15 minutes.'];
    }
    
    // Verify credentials against DB
    try {
        $stmt = $db->prepare("SELECT * FROM users WHERE username = ?");
        $stmt->execute([$username]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($user && password_verify($password, $user['password_hash'])) {
            // Successful login
            $_SESSION['authenticated'] = true;
            $_SESSION['user'] = $user['username'];
            $_SESSION['role'] = $user['role'];
            $_SESSION['client_name'] = $user['client_name'];
            $_SESSION['ip'] = $_SERVER['REMOTE_ADDR'];
            $_SESSION['login_time'] = time();
            
            // Clear failed attempts
            if (file_exists($attempts_file)) {
                @unlink($attempts_file);
            }
            
            error_log("WebUI: Successful login from " . $_SERVER['REMOTE_ADDR'] . " as " . $username . " (" . $user['role'] . ")");
            return ['success' => true];
        }
    } catch (PDOException $e) {
        error_log("WebUI: Login query failed: " . $e->getMessage());
    }
    
    // Failed login - increment attempts
    $attempts++;
    file_put_contents($attempts_file, json_encode([
        'attempts' => $attempts,
        'last_attempt' => time()
    ]));
    
    error_log("WebUI: Failed login attempt from " . $_SERVER['REMOTE_ADDR'] . " for user " . $username);
    return ['success' => false, 'message' => 'Invalid username or password.'];
}

// Logout function
function logout() {
    session_unset();
    session_destroy();
    session_start();
}

// Require authentication
function require_auth() {
    if (!is_authenticated()) {
        if (php_sapi_name() !== 'cli') {
            header('Location: /login.php');
            exit;
        }
    }
}

// Require administrator access
function require_admin() {
    require_auth();
    if (!is_admin()) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Forbidden: Administrator privileges required']);
        exit;
    }
}

// Escape shell arguments
function escape_shell_arg($arg) {
    return escapeshellarg($arg);
}

// Sanitize input
function sanitize_input($input, $type = 'string') {
    switch ($type) {
        case 'int':
            return filter_var($input, FILTER_SANITIZE_NUMBER_INT);
        case 'email':
            return filter_var($input, FILTER_SANITIZE_EMAIL);
        case 'url':
            return filter_var($input, FILTER_SANITIZE_URL);
        case 'string':
        default:
            return htmlspecialchars(strip_tags($input), ENT_QUOTES, 'UTF-8');
    }
}

// Validate client name (alphanumeric and underscores only)
function validate_client_name($name) {
    return preg_match('/^[a-zA-Z0-9_-]+$/', $name) && strlen($name) <= 50;
}

// Validate container name
function validate_container_name($name) {
    return preg_match('/^[a-zA-Z0-9._-]+$/', $name) && strlen($name) <= 255;
}

// Get client IP address (considering proxies)
function get_client_ip() {
    $ip_keys = ['HTTP_X_FORWARDED_FOR', 'HTTP_X_REAL_IP', 'HTTP_CLIENT_IP', 'REMOTE_ADDR'];
    foreach ($ip_keys as $key) {
        if (!empty($_SERVER[$key])) {
            $ip = trim(explode(',', $_SERVER[$key])[0]);
            if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
                return $ip;
            }
        }
    }
    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

