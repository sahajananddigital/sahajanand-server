<?php
/**
 * Redis Object Cache for WordPress
 * Shared across all clients
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Check if Redis is available
if (!class_exists('Redis')) {
    return;
}

class Redis_Object_Cache {
    private $redis;
    private $prefix;
    private $host;
    private $port;
    private $database;
    private $timeout;
    private $read_timeout;
    private $database_timeout;
    private $connected = false;

    public function __construct() {
        $this->host = defined('WP_REDIS_HOST') ? WP_REDIS_HOST : 'redis';
        $this->port = defined('WP_REDIS_PORT') ? WP_REDIS_PORT : 6379;
        $this->database = defined('WP_REDIS_DATABASE') ? WP_REDIS_DATABASE : 0;
        $this->timeout = defined('WP_REDIS_TIMEOUT') ? WP_REDIS_TIMEOUT : 1;
        $this->read_timeout = defined('WP_REDIS_READ_TIMEOUT') ? WP_REDIS_READ_TIMEOUT : 1;
        $this->database_timeout = defined('WP_REDIS_DATABASE_TIMEOUT') ? WP_REDIS_DATABASE_TIMEOUT : 0.5;
        $this->prefix = defined('WP_REDIS_PREFIX') ? WP_REDIS_PREFIX : 'wp:';
        
        $this->connect();
    }

    private function connect() {
        try {
            $this->redis = new Redis();
            $this->redis->connect($this->host, $this->port, $this->timeout);
            $this->redis->select($this->database);
            $this->redis->setOption(Redis::OPT_READ_TIMEOUT, $this->read_timeout);
            $this->connected = true;
        } catch (Exception $e) {
            $this->connected = false;
        }
    }

    public function get($key) {
        if (!$this->connected) {
            return false;
        }

        try {
            $value = $this->redis->get($this->prefix . $key);
            return $value !== false ? maybe_unserialize($value) : false;
        } catch (Exception $e) {
            return false;
        }
    }

    public function set($key, $value, $expiration = 0) {
        if (!$this->connected) {
            return false;
        }

        try {
            $value = maybe_serialize($value);
            if ($expiration > 0) {
                return $this->redis->setex($this->prefix . $key, $expiration, $value);
            } else {
                return $this->redis->set($this->prefix . $key, $value);
            }
        } catch (Exception $e) {
            return false;
        }
    }

    public function delete($key) {
        if (!$this->connected) {
            return false;
        }

        try {
            return $this->redis->del($this->prefix . $key);
        } catch (Exception $e) {
            return false;
        }
    }

    public function flush() {
        if (!$this->connected) {
            return false;
        }

        try {
            $keys = $this->redis->keys($this->prefix . '*');
            if (!empty($keys)) {
                return $this->redis->del($keys);
            }
            return true;
        } catch (Exception $e) {
            return false;
        }
    }
}

// Initialize the cache
$GLOBALS['wp_object_cache'] = new Redis_Object_Cache();

// WordPress cache functions
function wp_cache_get($key, $group = '') {
    global $wp_object_cache;
    return $wp_object_cache->get($group . ':' . $key);
}

function wp_cache_set($key, $value, $group = '', $expiration = 0) {
    global $wp_object_cache;
    return $wp_object_cache->set($group . ':' . $key, $value, $expiration);
}

function wp_cache_delete($key, $group = '') {
    global $wp_object_cache;
    return $wp_object_cache->delete($group . ':' . $key);
}

function wp_cache_flush() {
    global $wp_object_cache;
    return $wp_object_cache->flush();
}
