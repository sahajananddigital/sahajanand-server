<?php
/**
 * Sahajanand Server Management UI
 * Main dashboard interface
 */

// Determine includes path (works both in Docker and on host)
$isDocker = file_exists('/.dockerenv');
$includes_path = $isDocker ? '/var/www/webui/includes' : __DIR__ . '/../includes';

require_once $includes_path . '/config.php';
require_once $includes_path . '/auth.php';
require_once $includes_path . '/functions.php';

// Require authentication
require_auth();

// Set security headers
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');
header('Referrer-Policy: strict-origin-when-cross-origin');
header('Content-Security-Policy: default-src \'self\'; script-src \'self\' \'unsafe-inline\' https://cdn.tailwindcss.com https://unpkg.com https://cdnjs.cloudflare.com; style-src \'self\' \'unsafe-inline\' https://cdn.tailwindcss.com https://cdnjs.cloudflare.com; font-src \'self\' https://cdnjs.cloudflare.com; img-src \'self\' data:;');

$page = $_GET['page'] ?? 'dashboard';
$allowed_pages = ['dashboard', 'clients', 'databases', 'backups', 'system'];
if (!in_array($page, $allowed_pages)) {
    $page = 'dashboard';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sahajanand Server Management</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        [x-cloak] { display: none !important; }
        .nav-active {
            @apply bg-blue-600 text-white;
        }
        .nav-inactive {
            @apply text-gray-700 hover:bg-gray-100;
        }
    </style>
</head>
<body class="bg-gray-50">
    <div class="min-h-screen flex">
        <!-- Sidebar -->
        <div class="w-64 bg-white shadow-lg">
            <div class="p-6 border-b">
                <h1 class="text-2xl font-bold text-gray-800">
                    <i class="fas fa-server mr-2"></i>
                    Server Admin
                </h1>
                <p class="text-sm text-gray-500 mt-1">Management Portal</p>
            </div>
            <nav class="mt-6">
                <a href="?page=dashboard" class="block px-6 py-3 <?= $page === 'dashboard' ? 'nav-active' : 'nav-inactive' ?>">
                    <i class="fas fa-home mr-3"></i> Dashboard
                </a>
                <a href="?page=clients" class="block px-6 py-3 <?= $page === 'clients' ? 'nav-active' : 'nav-inactive' ?>">
                    <i class="fas fa-users mr-3"></i> Clients
                </a>
                <a href="?page=databases" class="block px-6 py-3 <?= $page === 'databases' ? 'nav-active' : 'nav-inactive' ?>">
                    <i class="fas fa-database mr-3"></i> Databases
                </a>
                <a href="?page=backups" class="block px-6 py-3 <?= $page === 'backups' ? 'nav-active' : 'nav-inactive' ?>">
                    <i class="fas fa-shield-alt mr-3"></i> Backups
                </a>
                <a href="?page=system" class="block px-6 py-3 <?= $page === 'system' ? 'nav-active' : 'nav-inactive' ?>">
                    <i class="fas fa-cog mr-3"></i> System
                </a>
                <div class="border-t border-gray-200 mt-4 pt-4">
                    <div class="px-6 py-2 text-sm text-gray-600">
                        <i class="fas fa-user mr-2"></i> <?= htmlspecialchars($_SESSION['user'] ?? 'User') ?>
                    </div>
                    <a href="/logout.php" class="block px-6 py-3 text-red-600 hover:bg-red-50">
                        <i class="fas fa-sign-out-alt mr-3"></i> Logout
                    </a>
                </div>
            </nav>
        </div>

        <!-- Main Content -->
        <div class="flex-1 overflow-auto">
            <div class="p-8">
                <?php
                switch ($page) {
                    case 'dashboard':
                        include $includes_path . '/dashboard.php';
                        break;
                    case 'clients':
                        include $includes_path . '/clients.php';
                        break;
                    case 'databases':
                        include $includes_path . '/databases.php';
                        break;
                    case 'backups':
                        include $includes_path . '/backups.php';
                        break;
                    case 'system':
                        include $includes_path . '/system.php';
                        break;
                }
                ?>
            </div>
        </div>
    </div>

    <script>
        // Get CSRF token
        function getCsrfToken() {
            return '<?= generate_csrf_token() ?>';
        }
        
        // Global API functions
        const api = {
            baseUrl: 'api/',
            
            async get(endpoint) {
                try {
                    const response = await fetch(this.baseUrl + endpoint);
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return await response.json();
                } catch (error) {
                    console.error('API GET error:', error);
                    return { success: false, message: 'Network error occurred' };
                }
            },
            
            async post(endpoint, data) {
                try {
                    // Add CSRF token to all POST requests
                    data.csrf_token = getCsrfToken();
                    const response = await fetch(this.baseUrl + endpoint, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(data)
                    });
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return await response.json();
                } catch (error) {
                    console.error('API POST error:', error);
                    return { success: false, message: 'Network error occurred' };
                }
            },
            
            async delete(endpoint) {
                try {
                    const response = await fetch(this.baseUrl + endpoint, {
                        method: 'DELETE',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ csrf_token: getCsrfToken() })
                    });
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return await response.json();
                } catch (error) {
                    console.error('API DELETE error:', error);
                    return { success: false, message: 'Network error occurred' };
                }
            }
        };

        // Notification system
        function showNotification(message, type = 'info') {
            const colors = {
                success: 'bg-green-500',
                error: 'bg-red-500',
                info: 'bg-blue-500',
                warning: 'bg-yellow-500'
            };
            
            const notification = document.createElement('div');
            notification.className = `fixed top-4 right-4 ${colors[type]} text-white px-6 py-3 rounded-lg shadow-lg z-50`;
            notification.textContent = message;
            document.body.appendChild(notification);
            
            setTimeout(() => {
                notification.remove();
            }, 3000);
        }

        // Auto-refresh for dashboard
        <?php if ($page === 'dashboard'): ?>
        setInterval(() => {
            location.reload();
        }, 30000); // Refresh every 30 seconds
        <?php endif; ?>
    </script>
</body>
</html>

