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
    <!-- Premium Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        [x-cloak] { display: none !important; }
        
        /* Premium Glassmorphic Dark UI Theme Overrides */
        body {
            background-color: #080c14 !important;
            color: #cbd5e1 !important;
            font-family: 'Outfit', 'Inter', sans-serif !important;
        }

        /* Custom scrollbar for deep space feel */
        ::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }
        ::-webkit-scrollbar-track {
            background: rgba(8, 12, 20, 0.5);
        }
        ::-webkit-scrollbar-thumb {
            background: rgba(255, 255, 255, 0.06);
            border-radius: 4px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: rgba(255, 255, 255, 0.12);
        }

        /* Glassmorphic Cards */
        .bg-white {
            background-color: rgba(15, 23, 42, 0.45) !important;
            backdrop-filter: blur(12px) !important;
            -webkit-backdrop-filter: blur(12px) !important;
            border: 1px solid rgba(255, 255, 255, 0.04) !important;
            border-radius: 1rem !important;
            box-shadow: 0 10px 30px -10px rgba(0, 0, 0, 0.5) !important;
            color: #f1f5f9 !important;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
        }

        .grid > .bg-white:hover, .flex-1 .bg-white:hover {
            border-color: rgba(99, 102, 241, 0.15) !important;
            transform: translateY(-2px);
            box-shadow: 0 15px 35px -10px rgba(0, 0, 0, 0.6) !important;
        }

        .shadow {
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3), 0 8px 10px -6px rgba(0, 0, 0, 0.3) !important;
        }

        /* Sidebar Styling */
        .w-64.bg-white {
            background-color: rgba(10, 15, 28, 0.95) !important;
            border-right: 1px solid rgba(255, 255, 255, 0.04) !important;
            transform: none !important;
            box-shadow: none !important;
            border-radius: 0 !important;
        }

        .w-64.bg-white .border-b {
            border-color: rgba(255, 255, 255, 0.04) !important;
        }

        /* Text Colors */
        .text-gray-800, .text-gray-700 {
            color: #f8fafc !important;
        }

        .text-gray-600, .text-gray-500 {
            color: #94a3b8 !important;
        }

        /* Tables & Borders */
        .bg-gray-50 {
            background-color: rgba(10, 15, 26, 0.6) !important;
            color: #94a3b8 !important;
        }

        .border, .border-b, .border-t, .border-r, .border-l, .divide-y > * + * {
            border-color: rgba(255, 255, 255, 0.05) !important;
        }

        .divide-gray-200 > * + * {
            border-color: rgba(255, 255, 255, 0.04) !important;
        }

        tr {
            transition: all 0.2s ease !important;
        }

        tr:hover {
            background-color: rgba(255, 255, 255, 0.02) !important;
        }

        /* Forms & Inputs */
        select, input, textarea {
            background-color: rgba(10, 15, 26, 0.8) !important;
            color: #f1f5f9 !important;
            border: 1px solid rgba(255, 255, 255, 0.08) !important;
            border-radius: 0.5rem !important;
            transition: all 0.2s ease !important;
        }

        select:focus, input:focus, textarea:focus {
            outline: none !important;
            border-color: #6366f1 !important;
            box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.25) !important;
        }

        /* Navigation Links */
        .nav-active {
            background: linear-gradient(135deg, #4f46e5 0%, #6366f1 100%) !important;
            box-shadow: 0 4px 20px rgba(99, 102, 241, 0.35) !important;
            color: #ffffff !important;
            border-radius: 0.75rem !important;
            margin: 0.35rem 0.75rem !important;
            padding: 0.75rem 1rem !important;
            transition: all 0.2s ease !important;
        }

        .nav-inactive {
            color: #94a3b8 !important;
            border-radius: 0.75rem !important;
            margin: 0.35rem 0.75rem !important;
            padding: 0.75rem 1rem !important;
            transition: all 0.2s ease !important;
        }

        .nav-inactive:hover {
            background-color: rgba(255, 255, 255, 0.04) !important;
            color: #ffffff !important;
        }

        /* Modals & Popups (Must be opaque dark to prevent bleed-through) */
        .bg-black.bg-opacity-50 {
            background-color: rgba(3, 7, 18, 0.8) !important;
            backdrop-filter: blur(8px) !important;
            -webkit-backdrop-filter: blur(8px) !important;
        }

        .fixed .bg-white {
            background-color: #0b0f19 !important;
            backdrop-filter: none !important;
            -webkit-backdrop-filter: none !important;
            border: 1px solid rgba(255, 255, 255, 0.08) !important;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.8) !important;
            color: #f1f5f9 !important;
            transform: none !important;
        }

        /* Action Buttons */
        .bg-blue-600 {
            background: linear-gradient(135deg, #4f46e5 0%, #6366f1 100%) !important;
            box-shadow: 0 4px 12px rgba(99, 102, 241, 0.2) !important;
            border: none !important;
            transition: all 0.2s ease !important;
        }
        
        .bg-blue-600:hover {
            background: linear-gradient(135deg, #4338ca 0%, #4f46e5 100%) !important;
            box-shadow: 0 4px 16px rgba(99, 102, 241, 0.3) !important;
            transform: translateY(-1px) !important;
        }

        .bg-gray-200 {
            background-color: rgba(255, 255, 255, 0.06) !important;
            color: #cbd5e1 !important;
            border: 1px solid rgba(255, 255, 255, 0.04) !important;
        }

        .bg-gray-200:hover {
            background-color: rgba(255, 255, 255, 0.1) !important;
            color: #ffffff !important;
        }

        /* Custom Stat Icon Cards */
        .stats-icon-bg {
            background: rgba(99, 102, 241, 0.08) !important;
            border: 1px solid rgba(99, 102, 241, 0.15) !important;
        }

        /* Pulsing Status Dot */
        .pulse-indicator {
            position: relative;
            display: inline-flex;
            height: 8px;
            width: 8px;
            border-radius: 50%;
            background-color: #10b981;
        }
        .pulse-indicator::after {
            content: '';
            position: absolute;
            width: 100%;
            height: 100%;
            border-radius: 50%;
            background-color: #10b981;
            animation: pulse-ring 1.5s cubic-bezier(0.215, 0.610, 0.355, 1) infinite;
        }
        @keyframes pulse-ring {
            0% { transform: scale(0.33); opacity: 1; }
            80%, 100% { transform: scale(3); opacity: 0; }
        }

        /* Stats Cards Translucent Badges Overrides */
        .bg-blue-100 { background-color: rgba(59, 130, 246, 0.15) !important; }
        .bg-green-100 { background-color: rgba(16, 185, 129, 0.15) !important; }
        .bg-purple-100 { background-color: rgba(139, 92, 246, 0.15) !important; }
        .bg-orange-100 { background-color: rgba(249, 115, 22, 0.15) !important; }
        .bg-red-100 { background-color: rgba(239, 68, 68, 0.15) !important; }

        /* Rich Saturated Neon Status Text Overrides */
        .text-blue-600 { color: #60a5fa !important; }
        .text-green-600 { color: #34d399 !important; }
        .text-purple-600 { color: #a78bfa !important; }
        .text-orange-600 { color: #fb923c !important; }
        .text-red-600 { color: #f87171 !important; }
        .text-yellow-600 { color: #fbbf24 !important; }
        
        .text-blue-800 { color: #93c5fd !important; }
        .text-green-800 { color: #a7f3d0 !important; }
        .text-purple-800 { color: #ddd6fe !important; }
        .text-orange-800 { color: #fed7aa !important; }
        .text-red-800 { color: #fecaca !important; }
    </style>
</head>
<body class="bg-gray-900">
    <div class="min-h-screen flex">
        <!-- Sidebar -->
        <div class="w-64 bg-white shadow-lg flex flex-col justify-between">
            <div>
                <div class="p-6 border-b flex items-center justify-between">
                    <div>
                        <h1 class="text-2xl font-bold text-gray-800 tracking-tight flex items-center">
                            <i class="fas fa-server mr-2 text-indigo-500"></i>
                            Server Admin
                        </h1>
                        <p class="text-xs text-gray-500 mt-1 uppercase tracking-wider font-semibold">Management Portal</p>
                    </div>
                    <span class="flex h-3 w-3 items-center justify-center" title="Server Online">
                        <span class="pulse-indicator"></span>
                    </span>
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

