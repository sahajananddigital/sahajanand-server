# Web UI Security Guide

This document outlines the security measures implemented in the Web UI and recommendations for production deployment.

## Implemented Security Features

### 1. Authentication System
- **Login Protection**: All pages and API endpoints require authentication
- **Password Hashing**: Uses PHP's `password_hash()` with bcrypt
- **Session Management**: Secure session handling with HttpOnly cookies
- **IP Validation**: Session IP is validated on each request
- **Session Regeneration**: Periodic session ID regeneration to prevent fixation

### 2. CSRF Protection
- **Token-based Protection**: All forms and API endpoints use CSRF tokens
- **Token Validation**: Tokens are validated on every POST request
- **Secure Generation**: Tokens are cryptographically secure (random_bytes)

### 3. Input Validation & Sanitization
- **Input Sanitization**: All user input is sanitized
- **Whitelist Validation**: Only allowed characters/patterns are accepted
- **Path Traversal Prevention**: Uses `basename()` to prevent directory traversal
- **Shell Injection Prevention**: All shell commands use `escapeshellarg()`

### 4. Brute Force Protection
- **Rate Limiting**: Maximum 5 failed login attempts per IP
- **Temporary Lockout**: 15-minute lockout after failed attempts
- **Attempt Tracking**: Failed attempts are logged per IP address

### 5. Security Headers
- **X-Content-Type-Options**: Prevents MIME type sniffing
- **X-Frame-Options**: Prevents clickjacking (DENY)
- **X-XSS-Protection**: Enables browser XSS filtering
- **Referrer-Policy**: Controls referrer information
- **Content-Security-Policy**: Restricts resource loading

### 6. Secure Session Configuration
- **HttpOnly Cookies**: Prevents JavaScript access to cookies
- **Secure Cookies**: Enabled when HTTPS is detected
- **SameSite**: Strict same-site cookie policy
- **Session Timeout**: Automatic session regeneration

## Production Security Checklist

### 1. Change Default Credentials

**CRITICAL**: Change the default username and password!

Create a `.webui_auth` file in the project root:

```bash
# Generate password hash
php -r "echo password_hash('your-secure-password', PASSWORD_DEFAULT);"
```

Create `.webui_auth`:
```
WEBUI_USERNAME=your-admin-username
WEBUI_PASSWORD_HASH=$2y$10$...your-generated-hash...
```

Or add to `.env`:
```
WEBUI_USERNAME=your-admin-username
WEBUI_PASSWORD_HASH=$2y$10$...your-generated-hash...
```

**Never commit `.webui_auth` to version control!** Add it to `.gitignore`.

### 2. Use HTTPS Only

In production, enforce HTTPS:

- Update Traefik configuration to redirect HTTP to HTTPS
- Use Let's Encrypt SSL certificates (automatic with Traefik)
- Set `session.cookie_secure = 1` in production

### 3. IP Whitelisting (Optional)

For maximum security, restrict access by IP. Add to Traefik middleware:

```yaml
# traefik/dynamic.yml
http:
  middlewares:
    webui-ipwhitelist:
      ipWhiteList:
        sourceRange:
          - "1.2.3.4/32"  # Your IP
          - "10.0.0.0/8"   # Internal network
```

Then add to docker-compose labels:
```yaml
- "traefik.http.routers.webui.middlewares=security-headers@file,gzip@file,webui-ipwhitelist@file"
```

### 4. Two-Factor Authentication (Recommended)

Consider implementing 2FA for additional security:
- Use a library like `sonata-project/google-authenticator`
- Add TOTP (Time-based One-Time Password) support
- Require 2FA for sensitive operations

### 5. Audit Logging

Enable comprehensive logging:

```php
// Already implemented - login attempts are logged
error_log("WebUI: Successful login from " . $_SERVER['REMOTE_ADDR']);
error_log("WebUI: Failed login attempt from " . $_SERVER['REMOTE_ADDR']);
```

Monitor logs:
```bash
docker logs webui 2>&1 | grep "WebUI:"
```

### 6. Regular Updates

- Keep PHP updated
- Keep Docker images updated
- Review security advisories regularly

### 7. File Permissions

Ensure proper file permissions:

```bash
# Web UI files
chmod 644 webui/**/*.php
chmod 755 webui/

# Auth file (readable only by owner)
chmod 600 .webui_auth

# .env file
chmod 600 .env
```

### 8. Network Security

- **Firewall**: Restrict access to Web UI port
- **VPN**: Consider requiring VPN access
- **Reverse Proxy**: Use Traefik or similar (already configured)
- **No Direct Exposure**: Never expose Web UI directly to internet

### 9. Docker Security

- **Non-root User**: Consider running container as non-root
- **Read-only Filesystem**: Use read-only mounts where possible
- **Resource Limits**: Set CPU/memory limits in docker-compose
- **Network Isolation**: Use Docker networks (already configured)

### 10. Backup Security

- **Encrypt Backups**: Consider encrypting backup files
- **Secure Storage**: Store backups in secure, encrypted storage
- **Access Control**: Limit backup file access permissions

## Security Best Practices

1. **Principle of Least Privilege**: Give minimum required permissions
2. **Defense in Depth**: Multiple layers of security
3. **Regular Audits**: Review logs and access patterns
4. **Incident Response**: Have a plan for security incidents
5. **Backup Authentication**: Keep backup credentials secure

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do NOT** create a public issue
2. Contact the maintainer privately
3. Provide detailed information
4. Allow time for fix before disclosure

## Additional Recommendations

### Strong Password Policy

Enforce strong passwords:
- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, symbols
- Not dictionary words
- Not reused passwords

### Session Management

- **Timeout**: Consider adding session timeout (currently regenerates every 30 min)
- **Single Session**: Optionally limit to one active session per user
- **Activity Monitoring**: Log all sensitive actions

### API Rate Limiting

Consider adding rate limiting for API endpoints:
- Limit requests per IP per minute
- Use Redis or similar for distributed rate limiting
- Different limits for different endpoints

### Security Headers

Additional headers to consider:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

## Compliance

For compliance requirements:
- **GDPR**: Ensure proper data handling and user consent
- **HIPAA**: Additional encryption and access controls may be required
- **PCI-DSS**: If handling payment data, stricter controls needed

## Testing Security

Regular security testing:
- **Penetration Testing**: Regular security audits
- **Vulnerability Scanning**: Automated scans for known vulnerabilities
- **Code Reviews**: Review code changes for security issues
- **Dependency Updates**: Keep dependencies updated

## Emergency Procedures

If a security breach is suspected:

1. **Immediately change passwords**
2. **Revoke all sessions**: Clear session data
3. **Review logs**: Check for unauthorized access
4. **Update credentials**: Change all credentials
5. **Notify users**: If user data is affected
6. **Patch vulnerabilities**: Apply security patches

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [PHP Security Guide](https://www.php.net/manual/en/security.php)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Traefik Security](https://doc.traefik.io/traefik/middlewares/security/)

