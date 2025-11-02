<?php
/**
 * Logout Handler
 */

$isDocker = file_exists('/.dockerenv');
$includes_path = $isDocker ? '/var/www/webui/includes' : __DIR__ . '/../includes';
require_once $includes_path . '/config.php';
require_once $includes_path . '/auth.php';

logout();

header('Location: /login.php?message=Logged out successfully');
exit;

