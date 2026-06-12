<?php
/**
 * Login Page
 */

$isDocker = file_exists('/.dockerenv');
$includes_path = $isDocker ? '/var/www/webui/includes' : __DIR__ . '/../includes';
require_once $includes_path . '/config.php';
require_once $includes_path . '/auth.php';

$error = '';
$message = '';

// Check if already logged in
if (is_authenticated()) {
    header('Location: /');
    exit;
}

// Handle login form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = sanitize_input($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $csrf_token = $_POST['csrf_token'] ?? '';
    
    // Validate CSRF token
    if (!validate_csrf_token($csrf_token)) {
        $error = 'Invalid security token. Please try again.';
    } else {
        // Attempt login
        $result = login($username, $password);
        if ($result['success']) {
            header('Location: /');
            exit;
        } else {
            $error = $result['message'] ?? 'Login failed.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Sahajanand Server Management</title>
    <!-- Premium Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        body {
            background-color: #080c14;
            color: #cbd5e1;
            font-family: 'Outfit', 'Inter', sans-serif;
        }
        .glass-panel {
            background-color: rgba(15, 23, 42, 0.45);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid rgba(255, 255, 255, 0.04);
            box-shadow: 0 20px 40px -15px rgba(0, 0, 0, 0.7);
        }
        .glow-orb {
            position: absolute;
            width: 400px;
            height: 400px;
            border-radius: 50%;
            background: radial-gradient(circle, rgba(99, 102, 241, 0.15) 0%, rgba(99, 102, 241, 0) 70%);
            filter: blur(40px);
            z-index: 0;
        }
        .glow-orb-2 {
            position: absolute;
            width: 300px;
            height: 300px;
            border-radius: 50%;
            background: radial-gradient(circle, rgba(139, 92, 246, 0.1) 0%, rgba(139, 92, 246, 0) 70%);
            filter: blur(30px);
            z-index: 0;
        }
        input {
            background-color: rgba(10, 15, 26, 0.8) !important;
            color: #f1f5f9 !important;
            border: 1px solid rgba(255, 255, 255, 0.08) !important;
            transition: all 0.2s ease !important;
        }
        input:focus {
            outline: none !important;
            border-color: #6366f1 !important;
            box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.25) !important;
        }
    </style>
</head>
<body class="min-h-screen flex items-center justify-center relative overflow-hidden px-4">
    <!-- Glowing background elements -->
    <div class="glow-orb -top-20 -left-20"></div>
    <div class="glow-orb-2 -bottom-20 -right-20"></div>
    
    <div class="glass-panel rounded-2xl p-8 w-full max-w-md relative z-10">
        <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 mb-4">
                <i class="fas fa-server text-3xl text-indigo-500"></i>
            </div>
            <h1 class="text-3xl font-bold text-slate-100 tracking-tight">Server Admin</h1>
            <p class="text-slate-400 mt-2 text-sm">Sign in to access management portal</p>
        </div>
 
        <?php if ($error): ?>
            <div class="bg-red-500/10 border border-red-500/20 text-red-400 px-4 py-3 rounded-lg mb-6 text-sm flex items-center gap-3">
                <i class="fas fa-exclamation-circle text-lg"></i>
                <span><?= htmlspecialchars($error) ?></span>
            </div>
        <?php endif; ?>
 
        <?php if ($message): ?>
            <div class="bg-green-500/10 border border-green-500/20 text-green-400 px-4 py-3 rounded-lg mb-6 text-sm flex items-center gap-3">
                <i class="fas fa-check-circle text-lg"></i>
                <span><?= htmlspecialchars($message) ?></span>
            </div>
        <?php endif; ?>
 
        <form method="POST" action="/login.php" class="space-y-5">
            <input type="hidden" name="csrf_token" value="<?= generate_csrf_token() ?>">
            
            <div>
                <label for="username" class="block text-sm font-medium text-slate-300 mb-2">
                    <i class="fas fa-user mr-2 text-slate-400"></i> Username
                </label>
                <input 
                    type="text" 
                    id="username" 
                    name="username" 
                    required 
                    autocomplete="username"
                    class="w-full px-4 py-2.5 rounded-lg text-slate-200 placeholder-slate-500 text-sm focus:ring-2 focus:ring-indigo-500/25 focus:border-indigo-500"
                    placeholder="Enter your username"
                    autofocus
                >
            </div>
 
            <div>
                <label for="password" class="block text-sm font-medium text-slate-300 mb-2">
                    <i class="fas fa-lock mr-2 text-slate-400"></i> Password
                </label>
                <input 
                    type="password" 
                    id="password" 
                    name="password" 
                    required 
                    autocomplete="current-password"
                    class="w-full px-4 py-2.5 rounded-lg text-slate-200 placeholder-slate-500 text-sm focus:ring-2 focus:ring-indigo-500/25 focus:border-indigo-500"
                    placeholder="Enter your password"
                >
            </div>
 
            <button 
                type="submit" 
                class="w-full bg-gradient-to-r from-indigo-600 to-violet-600 text-white py-3 rounded-lg font-semibold hover:from-indigo-500 hover:to-violet-500 transition duration-200 shadow-lg shadow-indigo-500/10 text-sm mt-2 flex items-center justify-center gap-2"
            >
                <i class="fas fa-sign-in-alt"></i> Sign In
            </button>
        </form>
 
        <div class="mt-8 text-center text-xs text-slate-500 flex items-center justify-center gap-1.5 border-t border-slate-800/60 pt-4">
            <i class="fas fa-shield-alt text-slate-600"></i>
            <span>Secure access protected</span>
        </div>
    </div>
 
    <script>
        // Prevent form resubmission on refresh
        if (window.history.replaceState) {
            window.history.replaceState(null, null, window.location.href);
        }
    </script>
</body>
</html>

