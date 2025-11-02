<?php
/**
 * phpMyAdmin Production Configuration
 * Forces MySQL username/password authentication - no auto-login
 */

// Force cookie-based authentication (requires manual login)
$cfg['Servers'][1]['auth_type'] = 'cookie';

// Do not allow connections without password
$cfg['Servers'][1]['AllowNoPassword'] = false;

// MySQL server connection
$cfg['Servers'][1]['host'] = 'mysql';
$cfg['Servers'][1]['port'] = '3306';

// Allow root user login
$cfg['Servers'][1]['AllowRoot'] = true;

// Cookie validity period (4 hours)
$cfg['LoginCookieValidity'] = 14400;

// Blowfish secret for cookie encryption (auto-generated, change in production)
// Generate with: openssl rand -base64 32
$cfg['blowfish_secret'] = 'CHANGE_THIS_SECRET_IN_PRODUCTION_USE_STRONG_RANDOM_STRING';

// Hide system databases from non-privileged users
$cfg['Servers'][1]['hide_db'] = '^(information_schema|performance_schema|mysql|sys)$';

// Security enhancements
$cfg['Servers'][1]['user'] = '';
$cfg['Servers'][1]['password'] = '';
// Empty user/password forces login prompt

