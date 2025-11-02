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

// Check if user is authenticated
function is_authenticated() {
    return isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true && 
           isset($_SESSION['user']) && 
           isset($_SESSION['ip']) && $_SESSION['ip'] === $_SERVER['REMOTE_ADDR'];
}

// Login function
function login($username, $password) {
    // Load credentials from environment or config
    $config_file = PROJECT_ROOT . '/.env';
    $auth_file = PROJECT_ROOT . '/.webui_auth';
    
    $stored_hash = null;
    $stored_username = null;
    
    // Try to load from .webui_auth file (preferred)
    if (file_exists($auth_file)) {
        $lines = file($auth_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        foreach ($lines as $line) {
            if (strpos($line, 'WEBUI_USERNAME=') === 0) {
                $stored_username = trim(substr($line, 15));
            } elseif (strpos($line, 'WEBUI_PASSWORD_HASH=') === 0) {
                $stored_hash = trim(substr($line, 20));
            }
        }
    }
    
    // Fallback to .env file
    if (!$stored_username || !$stored_hash) {
        if (file_exists($config_file)) {
            $lines = file($config_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                if (strpos($line, 'WEBUI_USERNAME=') === 0) {
                    $stored_username = trim(substr($line, 15));
                } elseif (strpos($line, 'WEBUI_PASSWORD_HASH=') === 0) {
                    $stored_hash = trim(substr($line, 20));
                }
            }
        }
    }
    
    // Default credentials (CHANGE THESE!)
    if (!$stored_username) {
        $stored_username = 'admin';
    }
    if (!$stored_hash) {
        // Default password: admin123 (CHANGE THIS!)
        $stored_hash = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi';
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
    
    // Verify credentials
    if ($username === $stored_username && password_verify($password, $stored_hash)) {
        // Successful login
        $_SESSION['authenticated'] = true;
        $_SESSION['user'] = $username;
        $_SESSION['ip'] = $_SERVER['REMOTE_ADDR'];
        $_SESSION['login_time'] = time();
        
        // Clear failed attempts
        if (file_exists($attempts_file)) {
            unlink($attempts_file);
        }
        
        // Log successful login
        error_log("WebUI: Successful login from " . $_SERVER['REMOTE_ADDR'] . " as " . $username);
        
        return ['success' => true];
    } else {
        // Failed login - increment attempts
        $attempts++;
        file_put_contents($attempts_file, json_encode([
            'attempts' => $attempts,
            'last_attempt' => time()
        ]));
        
        // Log failed login attempt
        error_log("WebUI: Failed login attempt from " . $_SERVER['REMOTE_ADDR'] . " for user " . $username);
        
        // Don't reveal which part failed
        return ['success' => false, 'message' => 'Invalid username or password.'];
    }
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

