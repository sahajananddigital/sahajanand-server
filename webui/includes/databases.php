<?php
$databases = get_client_databases();
$clients = get_clients();
?>

<div x-data="databaseManager()">
    <div class="mb-8 flex justify-between items-center">
        <div>
            <h2 class="text-3xl font-bold text-gray-800">Databases</h2>
            <p class="text-gray-600 mt-2">Manage MySQL databases for clients</p>
        </div>
        <button @click="showCreateModal = true" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
            <i class="fas fa-plus mr-2"></i> Create Database
        </button>
    </div>

    <!-- Databases List -->
    <div class="bg-white rounded-lg shadow">
        <div class="p-6 border-b">
            <h3 class="text-xl font-semibold text-gray-800">All Databases</h3>
        </div>
        <div class="p-6">
            <?php if (empty($databases)): ?>
                <p class="text-gray-500 text-center py-8">No databases found. Create a database for a client.</p>
            <?php else: ?>
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="bg-gray-50">
                            <tr>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Database</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Client</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Username</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Size</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach ($databases as $db): ?>
                            <tr>
                                <td class="px-4 py-3">
                                    <span class="font-medium text-gray-800"><?= htmlspecialchars($db['name']) ?></span>
                                </td>
                                <td class="px-4 py-3 text-gray-600">
                                    <?= htmlspecialchars($db['client']) ?>
                                </td>
                                <td class="px-4 py-3 text-gray-600">
                                    <?= htmlspecialchars($db['username']) ?>
                                </td>
                                <td class="px-4 py-3 text-gray-600">
                                    <?= number_format($db['size_mb'], 2) ?> MB
                                </td>
                                <td class="px-4 py-3">
                                    <div class="flex gap-2">
                                        <button @click="backupDatabase('<?= $db['name'] ?>', '<?= $db['client'] ?>')" class="text-blue-600 hover:text-blue-800" title="Backup">
                                            <i class="fas fa-download"></i>
                                        </button>
                                        <a href="?page=backups&type=database&client=<?= urlencode($db['client']) ?>" class="text-purple-600 hover:text-purple-800" title="View Backups">
                                            <i class="fas fa-list"></i>
                                        </a>
                                        <button @click="deleteDatabase('<?= $db['name'] ?>', '<?= $db['client'] ?>')" class="text-red-600 hover:text-red-800" title="Delete" onclick="return confirm('Are you sure? This cannot be undone!')">
                                            <i class="fas fa-trash"></i>
                                        </button>
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

    <!-- Create Database Modal -->
    <div x-show="showCreateModal" x-cloak class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 w-96" @click.away="showCreateModal = false">
            <h3 class="text-xl font-bold mb-4">Create Database</h3>
            <form @submit.prevent="createDatabase()">
                <div class="mb-4">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Select Client</label>
                    <select x-model="selectedClient" class="w-full border rounded-lg px-3 py-2" required>
                        <option value="">Choose a client...</option>
                        <?php foreach ($clients as $client): ?>
                            <?php
                            $has_db = false;
                            foreach ($databases as $db) {
                                if ($db['client'] === $client['name']) {
                                    $has_db = true;
                                    break;
                                }
                            }
                            ?>
                            <?php if (!$has_db): ?>
                                <option value="<?= htmlspecialchars($client['name']) ?>"><?= htmlspecialchars($client['name']) ?></option>
                            <?php endif; ?>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="mb-4">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Password (optional)</label>
                    <input type="password" x-model="password" class="w-full border rounded-lg px-3 py-2" placeholder="Leave blank for default">
                </div>
                <div class="flex gap-2">
                    <button type="submit" class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
                        Create
                    </button>
                    <button type="button" @click="showCreateModal = false" class="bg-gray-200 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-300">
                        Cancel
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<script>
function databaseManager() {
    return {
        showCreateModal: false,
        selectedClient: '',
        password: '',
        
        async createDatabase() {
            if (!this.selectedClient) return;
            
            try {
                const result = await api.post('databases.php', {
                    action: 'create',
                    client: this.selectedClient,
                    password: this.password
                });
                showNotification(result.message || 'Database created', result.success ? 'success' : 'error');
                if (result.success) {
                    this.showCreateModal = false;
                    this.selectedClient = '';
                    this.password = '';
                    setTimeout(() => location.reload(), 1000);
                }
            } catch (error) {
                showNotification('Error creating database', 'error');
            }
        },
        
        async backupDatabase(dbName, clientName) {
            try {
                const result = await api.post('backups.php', {
                    action: 'create',
                    type: 'database',
                    client: clientName
                });
                showNotification(result.message || 'Backup started', result.success ? 'success' : 'error');
            } catch (error) {
                showNotification('Error creating backup', 'error');
            }
        },
        
        async deleteDatabase(dbName, clientName) {
            if (!confirm(`Are you sure you want to delete database ${dbName}? This action cannot be undone!`)) {
                return;
            }
            
            try {
                const result = await api.post('databases.php', {
                    action: 'delete',
                    name: dbName,
                    client: clientName
                });
                showNotification(result.message || 'Database deleted', result.success ? 'success' : 'error');
                if (result.success) {
                    setTimeout(() => location.reload(), 1000);
                }
            } catch (error) {
                showNotification('Error deleting database', 'error');
            }
        }
    };
}
</script>

