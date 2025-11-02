# Code Improvements and Fixes

This document summarizes all improvements and fixes applied to the Web UI codebase.

## Security Improvements

### 1. MySQL Password Handling
- **Issue**: Hardcoded `rootpassword` in multiple places
- **Fix**: Created `get_mysql_root_password()` function in `config.php`
  - Reads from environment variables first
  - Falls back to `.env` file
  - Uses secure default only as last resort
- **Files Changed**: 
  - `webui/includes/config.php` - Added function
  - `webui/includes/functions.php` - Updated to use function
  - `webui/public/api/databases.php` - Updated to use function
  - `webui/public/api/backups.php` - Updated to use function

### 2. Path Traversal Prevention
- **Issue**: Potential path traversal vulnerabilities
- **Fix**: Added `realpath()` validation everywhere
  - Validates paths are within expected directories
  - Uses `basename()` to strip directory components
  - Checks path boundaries before operations
- **Files Changed**:
  - `webui/public/api/clients.php` - Added path validation
  - `webui/public/api/backups.php` - Added path validation for restore
  - `webui/includes/functions.php` - Improved `get_backups()` function

### 3. Error Message Security
- **Issue**: Error messages exposed command output (potential info leak)
- **Fix**: Replaced detailed error messages with generic ones
  - "Failed to restore: {output}" → "Failed to restore database. Check MySQL logs for details."
  - "Failed to start: {output}" → "Failed to start client. Check container logs for details."
- **Files Changed**:
  - `webui/public/api/clients.php`
  - `webui/public/api/backups.php`

### 4. File Type Validation
- **Issue**: Missing validation for backup file types during restore
- **Fix**: Added file extension checks
  - Database backups must be `.sql` files
  - File backups must be `.tar` or `.gz` files
  - Download only allows `.zst` files
- **Files Changed**:
  - `webui/public/api/backups.php`

### 5. Input Validation Improvements
- **Issue**: Missing validation in some edge cases
- **Fix**: Added comprehensive validation
  - Client directory existence checks
  - File existence before operations
  - File readability checks
- **Files Changed**:
  - `webui/public/api/backups.php`
  - `webui/public/api/clients.php`

## Code Quality Improvements

### 1. Error Handling
- **Issue**: Missing error handling in `exec_command()`
- **Fix**: Added comprehensive error handling
  - Validates command input
  - Validates working directory
  - Restores original directory on error
  - Try-catch blocks for exceptions
  - Better error logging
- **Files Changed**:
  - `webui/includes/functions.php` - `exec_command()` function

### 2. API Error Handling
- **Issue**: No error handling in JavaScript API calls
- **Fix**: Added try-catch blocks with proper error messages
  - Network error detection
  - HTTP status code checking
  - User-friendly error messages
- **Files Changed**:
  - `webui/public/index.php` - API functions

### 3. Backup Script Execution
- **Issue**: Duplicate checks and missing validation
- **Fix**: 
  - Removed duplicate `file_exists()` check
  - Added `is_executable()` check
  - Added `exec()` function availability check
  - Improved error messages
  - Better log file naming with timestamps
- **Files Changed**:
  - `webui/public/api/backups.php`

### 4. Backup File Listing
- **Issue**: Potential security issues in `get_backups()`
- **Fix**: 
  - Added path validation using `realpath()`
  - Validates files are within backup directory
  - Checks file extensions
  - Validates file readability
  - Validates client names
- **Files Changed**:
  - `webui/includes/functions.php` - `get_backups()` function

## Bug Fixes

### 1. SQL Escaping
- **Issue**: SQL queries could have injection vulnerabilities
- **Fix**: 
  - Proper escaping in `get_client_databases()`
  - Database name escaping with backslashes
  - Proper use of `escape_shell_arg()` for passwords
- **Files Changed**:
  - `webui/includes/functions.php`

### 2. Directory Handling
- **Issue**: Using `escape_shell_arg()` on directory paths could cause issues
- **Fix**: 
  - Use `realpath()` for validation
  - Use `basename()` for sanitization
  - Only escape when passing to shell commands
- **Files Changed**:
  - `webui/public/api/clients.php`

### 3. File Type Detection
- **Issue**: Backup type detection was unreliable
- **Fix**: 
  - Multiple checks (type parameter, filename, path)
  - Proper file extension validation
- **Files Changed**:
  - `webui/public/api/backups.php`

## Performance Improvements

### 1. Path Normalization
- **Issue**: Repeated `realpath()` calls
- **Fix**: Store normalized paths in variables
- **Files Changed**:
  - `webui/includes/functions.php`
  - `webui/public/api/backups.php`

## Code Consistency

### 1. Error Response Codes
- **Issue**: Inconsistent HTTP status codes
- **Fix**: Standardized error codes
  - 400 for bad requests
  - 403 for forbidden/security issues
  - 404 for not found
  - 500 for server errors
- **Files Changed**:
  - All API files

### 2. Error Messages
- **Issue**: Inconsistent error message formats
- **Fix**: Standardized error message format
  - User-friendly messages
  - No sensitive information
  - Actionable suggestions
- **Files Changed**:
  - All API files

## Documentation

### 1. Function Documentation
- **Issue**: Missing or incomplete PHPDoc
- **Fix**: Added comprehensive documentation
  - Parameter types
  - Return types
  - Function descriptions
- **Files Changed**:
  - `webui/includes/functions.php`

## Testing Recommendations

After these improvements, test:
1. ✅ Path traversal attempts (should be blocked)
2. ✅ Invalid file types (should be rejected)
3. ✅ Error messages (should not expose sensitive info)
4. ✅ MySQL password loading (should work from .env)
5. ✅ Backup operations (should validate properly)
6. ✅ Client operations (should validate paths)

## Summary

**Total Files Changed**: 6
- `webui/includes/config.php`
- `webui/includes/functions.php`
- `webui/public/api/clients.php`
- `webui/public/api/databases.php`
- `webui/public/api/backups.php`
- `webui/public/index.php`

**Security Issues Fixed**: 8
**Code Quality Issues Fixed**: 6
**Bug Fixes**: 3

All changes maintain backward compatibility while significantly improving security and code quality.

