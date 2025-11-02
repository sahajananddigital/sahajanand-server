<?php
$client_filter = $_GET['client'] ?? null;
$backups = get_backups($client_filter);
$clients = get_clients();
?>

<div x-data="backupManager()">
    <div class="mb-8 flex justify-between items-center">
        <div>
            <h2 class="text-3xl font-bold text-gray-800">Backups</h2>
            <p class="text-gray-600 mt-2">Manage database and file backups</p>
        </div>
        <div class="flex gap-2">
            <select x-model="selectedClient" @change="filterByClient()" class="border rounded-lg px-3 py-2">
                <option value="">All Clients</option>
                <?php foreach ($clients as $client): ?>
                    <option value="<?= htmlspecialchars($client['name']) ?>" <?= ($client_filter === $client['name']) ? 'selected' : '' ?>>
                        <?= htmlspecialchars($client['name']) ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <button @click="createBackup()" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
                <i class="fas fa-plus mr-2"></i> Create Backup
            </button>
        </div>
    </div>

    <!-- Create Backup Modal -->
    <div x-show="showBackupModal" x-cloak class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 w-96" @click.away="showBackupModal = false">
            <h3 class="text-xl font-bold mb-4">Create Backup</h3>
            <form @submit.prevent="submitBackup()">
                <div class="mb-4">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Select Client</label>
                    <select x-model="backupClient" class="w-full border rounded-lg px-3 py-2" required>
                        <option value="">Choose a client...</option>
                        <?php foreach ($clients as $client): ?>
                            <option value="<?= htmlspecialchars($client['name']) ?>"><?= htmlspecialchars($client['name']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="mb-4">
                    <label class="block text-sm font-medium text-gray-700 mb-2">Backup Type</label>
                    <select x-model="backupType" class="w-full border rounded-lg px-3 py-2" required>
                        <option value="all">All (Database + Files)</option>
                        <option value="database">Database Only</option>
                        <option value="files">Files Only</option>
                    </select>
                </div>
                <div class="flex gap-2">
                    <button type="submit" class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
                        Create Backup
                    </button>
                    <button type="button" @click="showBackupModal = false" class="bg-gray-200 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-300">
                        Cancel
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- Backups List -->
    <div class="bg-white rounded-lg shadow">
        <div class="p-6 border-b">
            <h3 class="text-xl font-semibold text-gray-800">
                <?= $client_filter ? "Backups for: " . htmlspecialchars($client_filter) : "All Backups" ?>
            </h3>
        </div>
        <div class="p-6">
            <?php if (empty($backups)): ?>
                <p class="text-gray-500 text-center py-8">No backups found.</p>
            <?php else: ?>
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="bg-gray-50">
                            <tr>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Client</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Filename</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Size</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach ($backups as $backup): ?>
                            <tr>
                                <td class="px-4 py-3">
                                    <span class="font-medium text-gray-800"><?= htmlspecialchars($backup['client']) ?></span>
                                </td>
                                <td class="px-4 py-3">
                                    <span class="px-2 py-1 text-xs font-semibold rounded-full 
                                        <?= $backup['type'] === 'database' ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800' ?>">
                                        <?= htmlspecialchars($backup['type']) ?>
                                    </span>
                                </td>
                                <td class="px-4 py-3 text-gray-600 text-sm">
                                    <?= htmlspecialchars($backup['filename']) ?>
                                </td>
                                <td class="px-4 py-3 text-gray-600">
                                    <?= format_size($backup['size']) ?>
                                </td>
                                <td class="px-4 py-3 text-gray-600 text-sm">
                                    <?= htmlspecialchars($backup['date']) ?>
                                </td>
                                <td class="px-4 py-3">
                                    <div class="flex gap-2">
                                        <button @click="downloadBackup('<?= htmlspecialchars($backup['path'], ENT_QUOTES) ?>')" class="text-blue-600 hover:text-blue-800" title="Download">
                                            <i class="fas fa-download"></i>
                                        </button>
                                        <button @click="restoreBackup('<?= $backup['client'] ?>', '<?= htmlspecialchars($backup['path'], ENT_QUOTES) ?>', '<?= $backup['type'] ?>')" class="text-green-600 hover:text-green-800" title="Restore">
                                            <i class="fas fa-upload"></i>
                                        </button>
                                        <button @click="deleteBackup('<?= htmlspecialchars($backup['path'], ENT_QUOTES) ?>')" class="text-red-600 hover:text-red-800" title="Delete" onclick="return confirm('Are you sure?')">
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
</div>

<script>
function backupManager() {
    return {
        showBackupModal: false,
        selectedClient: '<?= htmlspecialchars($client_filter ?? '') ?>',
        backupClient: '',
        backupType: 'all',
        
        filterByClient() {
            if (this.selectedClient) {
                window.location.href = '?page=backups&client=' + encodeURIComponent(this.selectedClient);
            } else {
                window.location.href = '?page=backups';
            }
        },
        
        createBackup() {
            this.showBackupModal = true;
        },
        
        async submitBackup() {
            if (!this.backupClient) return;
            
            try {
                const result = await api.post('backups.php', {
                    action: 'create',
                    client: this.backupClient,
                    type: this.backupType
                });
                showNotification(result.message || 'Backup created', result.success ? 'success' : 'error');
                if (result.success) {
                    this.showBackupModal = false;
                    this.backupClient = '';
                    this.backupType = 'all';
                    setTimeout(() => location.reload(), 2000);
                }
            } catch (error) {
                showNotification('Error creating backup', 'error');
            }
        },
        
        downloadBackup(path) {
            window.location.href = 'api/backups.php?action=download&path=' + encodeURIComponent(path);
        },
        
        async restoreBackup(client, path, type) {
            if (!confirm(`Are you sure you want to restore this backup? This will overwrite existing data for ${client}!`)) {
                return;
            }
            
            try {
                const result = await api.post('backups.php', {
                    action: 'restore',
                    client: client,
                    path: path,
                    type: type
                });
                showNotification(result.message || 'Restore started', result.success ? 'success' : 'error');
            } catch (error) {
                showNotification('Error restoring backup', 'error');
            }
        },
        
        async deleteBackup(path) {
            if (!confirm('Are you sure you want to delete this backup?')) {
                return;
            }
            
            try {
                const result = await api.post('backups.php', {
                    action: 'delete',
                    path: path
                });
                showNotification(result.message || 'Backup deleted', result.success ? 'success' : 'error');
                if (result.success) {
                    setTimeout(() => location.reload(), 1000);
                }
            } catch (error) {
                showNotification('Error deleting backup', 'error');
            }
        }
    };
}
</script>

