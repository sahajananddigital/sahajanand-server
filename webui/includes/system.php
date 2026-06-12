<?php
$containers = get_containers();
$system_info = get_system_info();
$clients = get_clients();

// Multi-tenant filtering
$user_client = get_user_client();
if ($user_client !== null) {
    $containers = array_filter($containers, fn($c) => strpos($c['name'], $user_client) !== false);
    $clients = array_filter($clients, fn($c) => $c['name'] === $user_client);
}

// Fetch SQLite users for User Management (admins only)
$db = get_db();
$users = [];
if ($db && is_admin()) {
    try {
        $stmt = $db->query("SELECT * FROM users ORDER BY username ASC");
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (PDOException $e) {
        error_log("WebUI: Failed to fetch users: " . $e->getMessage());
    }
}
?>

<div x-data="{ loading: false }">
    <div class="mb-8">
        <h2 class="text-3xl font-bold text-gray-800">System</h2>
        <p class="text-gray-600 mt-2">System status and container management</p>
    </div>

    <!-- System Info & Quick Actions -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <?php if (is_admin()): ?>
        <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-xl font-semibold text-gray-800 mb-4">System Information</h3>
            <div class="space-y-3">
                <div class="flex justify-between">
                    <span class="text-gray-600">PHP Version:</span>
                    <span class="font-medium"><?= htmlspecialchars($system_info['php_version']) ?></span>
                </div>
                <div class="flex justify-between">
                    <span class="text-gray-600">Docker:</span>
                    <span class="font-medium"><?= htmlspecialchars($system_info['docker_version']) ?></span>
                </div>
                <div class="flex justify-between">
                    <span class="text-gray-600">Server Time:</span>
                    <span class="font-medium"><?= htmlspecialchars($system_info['server_time']) ?></span>
                </div>
            </div>
        </div>
        <?php endif; ?>

        <div class="bg-white rounded-lg shadow p-6 <?= is_admin() ? '' : 'lg:col-span-2' ?>">
            <h3 class="text-xl font-semibold text-gray-800 mb-4">Quick Actions</h3>
            <div class="space-y-2">
                <button onclick="location.reload()" class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 font-medium">
                    <i class="fas fa-sync mr-2"></i> Refresh Status
                </button>
                <a href="?page=backups" class="block w-full bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 text-center font-medium">
                    <i class="fas fa-shield-alt mr-2"></i> Manage Backups
                </a>
            </div>
        </div>
    </div>

    <!-- Containers -->
    <div class="bg-white rounded-lg shadow mb-8">
        <div class="p-6 border-b">
            <h3 class="text-xl font-semibold text-gray-800">Docker Containers</h3>
        </div>
        <div class="p-6">
            <div class="overflow-x-auto">
                <table class="w-full">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Image</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Ports</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                        <?php foreach ($containers as $container): ?>
                        <tr>
                            <td class="px-4 py-3">
                                <span class="font-medium text-gray-800"><?= htmlspecialchars($container['name']) ?></span>
                            </td>
                            <td class="px-4 py-3 text-gray-600 text-sm">
                                <?= htmlspecialchars($container['image']) ?>
                            </td>
                            <td class="px-4 py-3">
                                <?php if ($container['state'] === 'running'): ?>
                                    <span class="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                                        Running
                                    </span>
                                <?php else: ?>
                                    <span class="px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
                                        Stopped
                                    </span>
                                <?php endif; ?>
                            </td>
                            <td class="px-4 py-3 text-gray-600 text-sm">
                                <?= htmlspecialchars($container['ports']) ?: 'N/A' ?>
                            </td>
                            <td class="px-4 py-3">
                                <div class="flex gap-2">
                                    <?php if ($container['state'] === 'running'): ?>
                                        <button onclick="stopContainer('<?= $container['name'] ?>')" class="text-yellow-600 hover:text-yellow-800" title="Stop">
                                            <i class="fas fa-stop"></i>
                                        </button>
                                        <button onclick="restartContainer('<?= $container['name'] ?>')" class="text-blue-600 hover:text-blue-800" title="Restart">
                                            <i class="fas fa-redo"></i>
                                        </button>
                                    <?php else: ?>
                                        <button onclick="startContainer('<?= $container['name'] ?>')" class="text-green-600 hover:text-green-800" title="Start">
                                            <i class="fas fa-play"></i>
                                        </button>
                                    <?php endif; ?>
                                    <button onclick="viewLogs('<?= $container['name'] ?>')" class="text-purple-600 hover:text-purple-800" title="Logs">
                                        <i class="fas fa-file-alt"></i>
                                    </button>
                                </div>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <?php if (is_admin()): ?>
    <!-- User Management Section (Admin Only) -->
    <div class="bg-white rounded-lg shadow mb-8" x-data="userManager()">
        <div class="p-6 border-b flex justify-between items-center">
            <h3 class="text-xl font-semibold text-gray-800">User Management</h3>
            <button @click="showAddUserModal = true" class="bg-blue-600 text-white px-3 py-1.5 rounded-lg hover:bg-blue-700 text-sm font-medium">
                <i class="fas fa-user-plus mr-1"></i> Add User
            </button>
        </div>
        <div class="p-6">
            <div class="overflow-x-auto">
                <table class="w-full text-sm">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Username</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Target Client</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200">
                        <?php foreach ($users as $u): ?>
                        <tr>
                            <td class="px-4 py-3">
                                <span class="font-medium text-gray-800"><?= htmlspecialchars($u['username']) ?></span>
                            </td>
                            <td class="px-4 py-3">
                                <span class="px-2.5 py-1 text-xs font-semibold rounded-full <?= $u['role'] === 'admin' ? 'bg-indigo-500/15 text-indigo-400' : 'bg-amber-500/15 text-amber-400' ?>">
                                    <?= htmlspecialchars(ucfirst($u['role'])) ?>
                                </span>
                            </td>
                            <td class="px-4 py-3 text-gray-400">
                                <?= htmlspecialchars($u['client_name'] ?? 'All (Admin)') ?>
                            </td>
                            <td class="px-4 py-3">
                                <?php if ($u['username'] !== $_SESSION['user']): ?>
                                <button @click="deleteUser(<?= $u['id'] ?>, '<?= htmlspecialchars($u['username']) ?>')" class="text-red-600 hover:text-red-800" title="Delete User">
                                    <i class="fas fa-trash"></i>
                                </button>
                                <?php else: ?>
                                <span class="text-xs text-gray-500 italic">Current Session</span>
                                <?php endif; ?>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Add User Modal -->
        <div x-show="showAddUserModal" x-cloak class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 px-4">
            <div class="bg-white rounded-lg p-6 w-full max-w-md" @click.away="!loading && (showAddUserModal = false)">
                <div class="flex justify-between items-center mb-6">
                    <h3 class="text-xl font-bold flex items-center text-indigo-400">
                        <i class="fas fa-user-plus mr-2 text-indigo-500"></i> Create New Web User
                    </h3>
                    <button @click="showAddUserModal = false" :disabled="loading" class="text-gray-400 hover:text-gray-200">
                        <i class="fas fa-times text-lg"></i>
                    </button>
                </div>
                <form @submit.prevent="addUser()">
                    <div class="space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-400 mb-1.5 font-semibold">Username</label>
                            <input type="text" x-model="username" class="w-full px-3 py-2 text-sm" placeholder="e.g. client1" required :disabled="loading">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-400 mb-1.5 font-semibold">Password</label>
                            <input type="password" x-model="password" class="w-full px-3 py-2 text-sm" placeholder="Password" required :disabled="loading">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-400 mb-1.5 font-semibold">User Role</label>
                            <select x-model="role" class="w-full px-3 py-2 text-sm" required :disabled="loading">
                                <option value="client">Client User (Restricted to Target Client App)</option>
                                <option value="admin">Administrator (Full Access)</option>
                            </select>
                        </div>
                        <div x-show="role === 'client'" x-transition>
                            <label class="block text-sm font-medium text-gray-400 mb-1.5 font-semibold">Target Client App</label>
                            <select x-model="clientName" class="w-full px-3 py-2 text-sm" :required="role === 'client'" :disabled="loading">
                                <option value="">Select app...</option>
                                <?php foreach ($clients as $c): ?>
                                <option value="<?= htmlspecialchars($c['name']) ?>"><?= htmlspecialchars($c['name']) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                    <div class="flex gap-3 mt-6 border-t border-gray-800 pt-4">
                        <button type="submit" class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 font-medium flex items-center justify-center gap-2" :disabled="loading">
                            <template x-if="loading">
                                <i class="fas fa-circle-notch animate-spin"></i>
                            </template>
                            <span x-text="loading ? 'Creating...' : 'Create User'"></span>
                        </button>
                        <button type="button" @click="showAddUserModal = false" :disabled="loading" class="bg-gray-200 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-300">
                            Cancel
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <script>
    function userManager() {
        return {
            showAddUserModal: false,
            loading: false,
            username: '',
            password: '',
            role: 'client',
            clientName: '',
            
            async addUser() {
                this.loading = true;
                try {
                    const result = await api.post('system.php', {
                        action: 'create_user',
                        username: this.username,
                        password: this.password,
                        role: this.role,
                        client_name: this.role === 'client' ? this.clientName : null
                    });
                    showNotification(result.message || 'User created', result.success ? 'success' : 'error');
                    if (result.success) {
                        this.showAddUserModal = false;
                        this.username = '';
                        this.password = '';
                        setTimeout(() => location.reload(), 1000);
                    }
                } catch (error) {
                    showNotification('Error creating user', 'error');
                } finally {
                    this.loading = false;
                }
            },
            
            async deleteUser(id, username) {
                if (!confirm(`Are you sure you want to delete user "${username}"?`)) return;
                
                try {
                    const result = await api.post('system.php', {
                        action: 'delete_user',
                        id: id
                    });
                    showNotification(result.message || 'User deleted', result.success ? 'success' : 'error');
                    if (result.success) {
                        setTimeout(() => location.reload(), 1000);
                    }
                } catch (error) {
                    showNotification('Error deleting user', 'error');
                }
            }
        };
    }
    </script>
    <?php endif; ?>

    <!-- Logs Modal -->
    <div id="logsModal" class="fixed inset-0 bg-black bg-opacity-50 hidden items-center justify-center z-50 px-4">
        <div class="bg-white rounded-lg p-6 w-full max-w-4xl max-h-[80vh] flex flex-col">
            <div class="flex justify-between items-center mb-4 border-b border-gray-800 pb-3">
                <h3 class="text-xl font-bold flex items-center text-indigo-400" id="logsTitle">
                    <i class="fas fa-terminal mr-2 text-indigo-500"></i> Container Logs
                </h3>
                <button onclick="closeLogs()" class="text-gray-400 hover:text-gray-200">
                    <i class="fas fa-times text-lg"></i>
                </button>
            </div>
            <pre id="logsContent" class="bg-[#05070c] text-emerald-400 p-4 rounded-lg overflow-auto text-xs font-mono border border-emerald-500/10 flex-1 min-h-[40vh] max-h-[60vh] leading-relaxed select-all"></pre>
        </div>
    </div>
</div>

<script>
async function startContainer(name) {
    try {
        const result = await api.post('system.php', { action: 'start', container: name });
        showNotification(result.message || 'Container started', result.success ? 'success' : 'error');
        if (result.success) {
            setTimeout(() => location.reload(), 1000);
        }
    } catch (error) {
        showNotification('Error starting container', 'error');
    }
}

async function stopContainer(name) {
    try {
        const result = await api.post('system.php', { action: 'stop', container: name });
        showNotification(result.message || 'Container stopped', result.success ? 'success' : 'error');
        if (result.success) {
            setTimeout(() => location.reload(), 1000);
        }
    } catch (error) {
        showNotification('Error stopping container', 'error');
    }
}

async function restartContainer(name) {
    try {
        const result = await api.post('system.php', { action: 'restart', container: name });
        showNotification(result.message || 'Container restarted', result.success ? 'success' : 'error');
        if (result.success) {
            setTimeout(() => location.reload(), 1000);
        }
    } catch (error) {
        showNotification('Error restarting container', 'error');
    }
}

async function viewLogs(name) {
    const modal = document.getElementById('logsModal');
    const title = document.getElementById('logsTitle');
    const content = document.getElementById('logsContent');
    
    title.textContent = `Logs: ${name}`;
    content.textContent = 'Loading...';
    modal.classList.remove('hidden');
    modal.classList.add('flex');
    
    try {
        const result = await api.get(`system.php?action=logs&container=${encodeURIComponent(name)}`);
        content.textContent = result.logs || 'No logs available';
    } catch (error) {
        content.textContent = 'Error loading logs';
    }
}

function closeLogs() {
    const modal = document.getElementById('logsModal');
    modal.classList.add('hidden');
    modal.classList.remove('flex');
}
</script>

