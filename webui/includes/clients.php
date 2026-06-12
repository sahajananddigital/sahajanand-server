<?php
$clients = get_clients();
$databases = get_client_databases();

// Multi-tenant filtering
$user_client = get_user_client();
if ($user_client !== null) {
    $clients = array_filter($clients, fn($c) => $c['name'] === $user_client);
    $databases = array_filter($databases, fn($db) => $db['client'] === $user_client);
}
?>

<div x-data="clientManager()">
    <div class="mb-8 flex justify-between items-center">
        <div>
            <h2 class="text-3xl font-bold text-gray-800">Clients</h2>
            <p class="text-gray-600 mt-2">Manage your PHP client applications</p>
        </div>
        <?php if (is_admin()): ?>
        <button @click="showAddModal = true" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
            <i class="fas fa-plus mr-2"></i> Add Client
        </button>
        <?php endif; ?>
    </div>

    <!-- Clients List -->
    <div class="bg-white rounded-lg shadow">
        <div class="p-6 border-b">
            <h3 class="text-xl font-semibold text-gray-800">All Clients</h3>
        </div>
        <div class="p-6">
            <?php if (empty($clients)): ?>
                <p class="text-gray-500 text-center py-8">No clients found. Add your first client to get started.</p>
            <?php else: ?>
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="bg-gray-50">
                            <tr>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Client Name</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Hostname</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Database</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach ($clients as $client): ?>
                            <tr>
                                <td class="px-4 py-3">
                                    <span class="font-medium text-gray-800"><?= htmlspecialchars($client['name']) ?></span>
                                </td>
                                <td class="px-4 py-3 text-gray-600">
                                    <?= htmlspecialchars($client['hostname'] ?? 'N/A') ?>
                                </td>
                                <td class="px-4 py-3">
                                    <?php if ($client['status'] === 'running'): ?>
                                        <span class="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                                            Running
                                        </span>
                                    <?php else: ?>
                                        <span class="px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
                                            Stopped
                                        </span>
                                    <?php endif; ?>
                                </td>
                                <td class="px-4 py-3">
                                    <?php
                                    $db_exists = false;
                                    $db_info = null;
                                    foreach ($databases as $db) {
                                        if ($db['client'] === $client['name']) {
                                            $db_exists = true;
                                            $db_info = $db;
                                            break;
                                        }
                                    }
                                    ?>
                                    <?php if ($db_exists): ?>
                                        <span class="text-green-600">
                                            <i class="fas fa-check mr-1"></i> <?= htmlspecialchars($db_info['name']) ?>
                                        </span>
                                    <?php else: ?>
                                        <span class="text-gray-400">
                                            <i class="fas fa-times mr-1"></i> No database
                                        </span>
                                    <?php endif; ?>
                                </td>
                                <td class="px-4 py-3">
                                    <div class="flex gap-2">
                                        <?php if ($client['status'] === 'running'): ?>
                                            <button @click="stopClient('<?= $client['name'] ?>')" class="text-yellow-600 hover:text-yellow-800" title="Stop">
                                                <i class="fas fa-stop"></i>
                                            </button>
                                        <?php else: ?>
                                            <button @click="startClient('<?= $client['name'] ?>')" class="text-green-600 hover:text-green-800" title="Start">
                                                <i class="fas fa-play"></i>
                                            </button>
                                        <?php endif; ?>
                                        <button @click="restartClient('<?= $client['name'] ?>')" class="text-blue-600 hover:text-blue-800" title="Restart">
                                            <i class="fas fa-redo"></i>
                                        </button>
                                        <a href="?page=backups&client=<?= urlencode($client['name']) ?>" class="text-purple-600 hover:text-purple-800" title="Backups">
                                            <i class="fas fa-shield-alt"></i>
                                        </a>
                                    </div>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </div>
    </div>

    <!-- Add Client Modal -->
    <div x-show="showAddModal" x-cloak class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 px-4">
        <div class="bg-white rounded-lg p-6 w-full max-w-md" @click.away="!loading && (showAddModal = false)">
            <div class="flex justify-between items-center mb-6">
                <h3 class="text-xl font-bold flex items-center text-indigo-400">
                    <i class="fas fa-rocket mr-2 text-indigo-500"></i> Deploy New Client
                </h3>
                <button @click="showAddModal = false" :disabled="loading" class="text-gray-400 hover:text-gray-200 disabled:opacity-50">
                    <i class="fas fa-times text-lg"></i>
                </button>
            </div>
            
            <form @submit.prevent="createClient()">
                <div class="space-y-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-400 mb-1.5">Client Name (alphanumeric/hyphen/underscore)</label>
                        <input type="text" x-model="name" class="w-full px-3 py-2 text-sm" placeholder="e.g. store-blog" required :disabled="loading">
                    </div>
                    
                    <div>
                        <label class="block text-sm font-medium text-gray-400 mb-1.5">Select App Template</label>
                        <select x-model="template" class="w-full px-3 py-2 text-sm" required :disabled="loading">
                            <option value="wordpress">WordPress / PHP Base App</option>
                            <option value="postiz">Postiz (Node + Postgres + Redis)</option>
                            <option value="erpnext">ERPNext (Frappe framework)</option>
                        </select>
                    </div>
                    
                    <div>
                        <label class="block text-sm font-medium text-gray-400 mb-1.5">Custom Domain (optional)</label>
                        <input type="text" x-model="domain" class="w-full px-3 py-2 text-sm" placeholder="e.g. blog.mydomain.com" :disabled="loading">
                        <span class="text-xs text-gray-500 mt-1 block">Defaults to: name.BASE_DOMAIN</span>
                    </div>

                    <div class="border-t border-gray-800 pt-4 mt-2">
                        <label class="flex items-center space-x-3 cursor-pointer">
                            <input type="checkbox" x-model="createDb" class="rounded border-gray-700 bg-gray-900 text-indigo-600 focus:ring-indigo-500 h-4 w-4" :disabled="loading">
                            <span class="text-sm font-medium text-gray-300">Provision SQLite Database</span>
                        </label>
                        <p class="text-xs text-gray-500 mt-1 pl-7">Creates an isolated database file under the client's database directory.</p>
                    </div>
                </div>

                <div class="flex gap-3 mt-6 border-t border-gray-800 pt-4">
                    <button type="submit" class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 font-medium flex items-center justify-center gap-2" :disabled="loading">
                        <template x-if="loading">
                            <i class="fas fa-circle-notch animate-spin"></i>
                        </template>
                        <span x-text="loading ? 'Deploying...' : 'Deploy Client'"></span>
                    </button>
                    <button type="button" @click="showAddModal = false" :disabled="loading" class="bg-gray-200 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-300 disabled:opacity-50">
                        Cancel
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<script>
function clientManager() {
    return {
        showAddModal: false,
        loading: false,
        name: '',
        template: 'wordpress',
        domain: '',
        createDb: true,
        dbPassword: '',
        
        async createClient() {
            if (!this.name) return;
            this.loading = true;
            try {
                const result = await api.post('clients.php', {
                    action: 'create',
                    name: this.name,
                    template: this.template,
                    domain: this.domain,
                    create_db: this.createDb,
                    db_password: this.dbPassword
                });
                showNotification(result.message || 'Client created', result.success ? 'success' : 'error');
                if (result.success) {
                    this.showAddModal = false;
                    this.name = '';
                    this.domain = '';
                    this.dbPassword = '';
                    setTimeout(() => location.reload(), 1500);
                }
            } catch (error) {
                showNotification('Error creating client', 'error');
            } finally {
                this.loading = false;
            }
        },
        
        async startClient(name) {
            try {
                const result = await api.post('clients.php', { action: 'start', name });
                showNotification(result.message || 'Client started', result.success ? 'success' : 'error');
                if (result.success) {
                    setTimeout(() => location.reload(), 1000);
                }
            } catch (error) {
                showNotification('Error starting client', 'error');
            }
        },
        
        async stopClient(name) {
            try {
                const result = await api.post('clients.php', { action: 'stop', name });
                showNotification(result.message || 'Client stopped', result.success ? 'success' : 'error');
                if (result.success) {
                    setTimeout(() => location.reload(), 1000);
                }
            } catch (error) {
                showNotification('Error stopping client', 'error');
            }
        },
        
        async restartClient(name) {
            try {
                const result = await api.post('clients.php', { action: 'restart', name });
                showNotification(result.message || 'Client restarted', result.success ? 'success' : 'error');
                if (result.success) {
                    setTimeout(() => location.reload(), 1000);
                }
            } catch (error) {
                showNotification('Error restarting client', 'error');
            }
        }
    };
}
</script>


