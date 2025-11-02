<?php
$clients = get_clients();
$databases = get_client_databases();
?>

<div x-data="clientManager()">
    <div class="mb-8 flex justify-between items-center">
        <div>
            <h2 class="text-3xl font-bold text-gray-800">Clients</h2>
            <p class="text-gray-600 mt-2">Manage your PHP client applications</p>
        </div>
        <button @click="showAddModal = true" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
            <i class="fas fa-plus mr-2"></i> Add Client
        </button>
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
    <div x-show="showAddModal" x-cloak class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 w-96" @click.away="showAddModal = false">
            <h3 class="text-xl font-bold mb-4">Add New Client</h3>
            <p class="text-gray-600 mb-4">To add a client, create a directory in the clients folder and add a docker-compose.yml file. See documentation for details.</p>
            <button @click="showAddModal = false" class="bg-gray-200 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-300">
                Close
            </button>
        </div>
    </div>
</div>

<script>
function clientManager() {
    return {
        showAddModal: false,
        
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

