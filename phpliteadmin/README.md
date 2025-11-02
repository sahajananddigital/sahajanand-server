# phpLiteAdmin Setup

phpLiteAdmin is a web-based SQLite database administration tool.

## Initial Setup

phpLiteAdmin needs to be downloaded and configured. Run the setup script:

```bash
cd phpliteadmin
./setup.sh
```

Or manually:

1. Download phpLiteAdmin:
```bash
cd phpliteadmin
wget -O phpliteadmin.php https://raw.githubusercontent.com/ovity/phpliteadmin/master/phpliteadmin.php
```

2. Set a secure password by editing `phpliteadmin.php`:
   - Search for `$password = '';`
   - Set a strong password: `$password = 'your-secure-password';`

## Configuration

Edit `phpliteadmin.php` to customize:

- **Password:** Change the default empty password
- **Database Directory:** Default is `$directory = '.';` - this points to `/var/www/html`
- **Subdirectories:** Set `$subdirectories = true;` to browse subdirectories

For accessing client databases:
- Client SQLite files are mounted at `/var/www/clients/`
- Navigate to `/clients/client1/database/` to access client1's SQLite databases
- Navigate to `/clients/client2/database/` to access client2's SQLite databases

## Access

Access phpLiteAdmin via Traefik:
- Local: `http://phpliteadmin.example.com`
- Production: `https://phpliteadmin.yourdomain.com`

Add to `/etc/hosts` for local development:
```
127.0.0.1 phpliteadmin.example.com
```

## Security Notes

1. **Change the default password** in `phpliteadmin.php`
2. **Restrict access** in production using firewall rules or IP restrictions
3. **Use HTTPS** in production (automatic via Traefik)
4. Consider adding authentication or IP whitelisting

## Troubleshooting

### Cannot access client databases

Ensure client databases are in the `database/` subdirectory:
```
clients/
  └── client1/
      └── database/
          └── app.db  ← SQLite file here
```

### Permission denied

The `clients` directory is mounted read-only for security. To write to SQLite databases, they must be created and managed from within the client containers.

