#!/bin/bash
set -e

# Wait for shared services
echo "Waiting for MariaDB..."
while ! nc -z mariadb-shared 3306; do
    sleep 1
done
echo "MariaDB is ready"

echo "Starting PHP-FPM..."
exec php-fpm
