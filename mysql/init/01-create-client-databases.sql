-- Create databases and users for each client
-- This script runs automatically when MySQL container starts for the first time
-- Add new clients by copying and modifying the client1 example below

-- Client 1 Database
CREATE DATABASE IF NOT EXISTS `client1_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'client1_user'@'%' IDENTIFIED BY 'client1_password';
GRANT ALL PRIVILEGES ON `client1_db`.* TO 'client1_user'@'%';
FLUSH PRIVILEGES;

-- Client 2 Database (example - uncomment and modify when adding client2)
-- CREATE DATABASE IF NOT EXISTS `client2_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- CREATE USER IF NOT EXISTS 'client2_user'@'%' IDENTIFIED BY 'client2_password';
-- GRANT ALL PRIVILEGES ON `client2_db`.* TO 'client2_user'@'%';
-- FLUSH PRIVILEGES;

-- Client 3 Database (example - uncomment and modify when adding client3)
-- CREATE DATABASE IF NOT EXISTS `client3_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- CREATE USER IF NOT EXISTS 'client3_user'@'%' IDENTIFIED BY 'client3_password';
-- GRANT ALL PRIVILEGES ON `client3_db`.* TO 'client3_user'@'%';
-- FLUSH PRIVILEGES;

