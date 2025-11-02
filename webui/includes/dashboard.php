<?php
$clients = get_clients();
$containers = get_containers();
$databases = get_client_databases();
$backups = get_backups();
$system_info = get_system_info();

$running_containers = array_filter($containers, fn($c) => $c['state'] === 'running');
$stopped_containers = array_filter($containers, fn($c) => $c['state'] !== 'running');
?>

<div x-data="{ loading: false }">
    <div class="mb-8">
        <h2 class="text-3xl font-bold text-gray-800">Dashboard</h2>
        <p class="text-gray-600 mt-2">Server overview and statistics</p>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-gray-600 text-sm">Total Clients</p>
                    <p class="text-3xl font-bold text-gray-800"><?= count($clients) ?></p>
                </div>
                <div class="bg-blue-100 p-3 rounded-full">
                    <i class="fas fa-users text-blue-600 text-2xl"></i>
                </div>
            </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-gray-600 text-sm">Running Containers</p>
                    <p class="text-3xl font-bold text-green-600"><?= count($running_containers) ?></p>
                </div>
                <div class="bg-green-100 p-3 rounded-full">
                    <i class="fas fa-check-circle text-green-600 text-2xl"></i>
                </div>
            </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-gray-600 text-sm">Databases</p>
                    <p class="text-3xl font-bold text-purple-600"><?= count($databases) ?></p>
                </div>
                <div class="bg-purple-100 p-3 rounded-full">
                    <i class="fas fa-database text-purple-600 text-2xl"></i>
                </div>
            </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between">
                <div>
                    <p class="text-gray-600 text-sm">Backups</p>
                    <p class="text-3xl font-bold text-orange-600"><?= count($backups) ?></p>
                </div>
                <div class="bg-orange-100 p-3 rounded-full">
                    <i class="fas fa-shield-alt text-orange-600 text-2xl"></i>
                </div>
            </div>
        </div>
    </div>

    <!-- Recent Clients -->
    <div class="bg-white rounded-lg shadow mb-8">
        <div class="p-6 border-b">
            <h3 class="text-xl font-semibold text-gray-800">Clients Overview</h3>
        </div>
        <div class="p-6">
            <?php if (empty($clients)): ?>
                <p class="text-gray-500 text-center py-8">No clients found</p>
            <?php else: ?>
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="bg-gray-50">
                            <tr>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Client</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Hostname</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Database</th>
                                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200">
                            <?php foreach (array_slice($clients, 0, 5) as $client): ?>
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
                                    foreach ($databases as $db) {
                                        if ($db['client'] === $client['name']) {
                                            $db_exists = true;
                                            break;
                                        }
                                    }
                                    ?>
                                    <?php if ($db_exists): ?>
                                        <i class="fas fa-check text-green-600"></i>
                                    <?php else: ?>
                                        <i class="fas fa-times text-red-600"></i>
                                    <?php endif; ?>
                                </td>
                                <td class="px-4 py-3">
                                    <a href="?page=clients" class="text-blue-600 hover:text-blue-800">
                                        <i class="fas fa-eye"></i> View
                                    </a>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
                <?php if (count($clients) > 5): ?>
                    <div class="mt-4 text-center">
                        <a href="?page=clients" class="text-blue-600 hover:text-blue-800">View all clients →</a>
                    </div>
                <?php endif; ?>
            <?php endif; ?>
        </div>
    </div>

    <!-- Container Status -->
    <div class="bg-white rounded-lg shadow">
        <div class="p-6 border-b">
            <h3 class="text-xl font-semibold text-gray-800">Container Status</h3>
        </div>
        <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <?php foreach (array_slice($containers, 0, 6) as $container): ?>
                <div class="border rounded-lg p-4">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="font-medium text-gray-800"><?= htmlspecialchars($container['name']) ?></p>
                            <p class="text-sm text-gray-500"><?= htmlspecialchars($container['image']) ?></p>
                        </div>
                        <div>
                            <?php if ($container['state'] === 'running'): ?>
                                <span class="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                                    Running
                                </span>
                            <?php else: ?>
                                <span class="px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
                                    Stopped
                                </span>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
                <?php endforeach; ?>
            </div>
        </div>
    </div>
</div>

