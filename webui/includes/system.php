<?php
$containers = get_containers();
$system_info = get_system_info();
$clients = get_clients();
?>

<div x-data="{ loading: false }">
    <div class="mb-8">
        <h2 class="text-3xl font-bold text-gray-800">System</h2>
        <p class="text-gray-600 mt-2">System status and container management</p>
    </div>

    <!-- System Info -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
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

        <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-xl font-semibold text-gray-800 mb-4">Quick Actions</h3>
            <div class="space-y-2">
                <button onclick="location.reload()" class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
                    <i class="fas fa-sync mr-2"></i> Refresh Status
                </button>
                <a href="?page=backups" class="block w-full bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 text-center">
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

    <!-- Logs Modal -->
    <div id="logsModal" class="fixed inset-0 bg-black bg-opacity-50 hidden items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 w-4/5 max-w-4xl max-h-[80vh] overflow-auto">
            <div class="flex justify-between items-center mb-4">
                <h3 class="text-xl font-bold" id="logsTitle">Container Logs</h3>
                <button onclick="closeLogs()" class="text-gray-500 hover:text-gray-700">
                    <i class="fas fa-times text-2xl"></i>
                </button>
            </div>
            <pre id="logsContent" class="bg-gray-900 text-green-400 p-4 rounded overflow-auto text-sm font-mono"></pre>
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

