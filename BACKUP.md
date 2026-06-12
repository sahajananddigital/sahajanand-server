# Backup Documentation

This document explains how to backup databases and client data using rclone with zstd compression.

## Overview

The backup script (`backup.sh`) automatically:
- Discovers all clients in the `clients/` directory
- Backs up each client's MySQL database separately
- Backs up each client's files (including SQLite databases)
- Compresses backups with zstd (level 10 compression)
- Uploads to rclone remote with separate directories per client

## Prerequisites

1. **rclone** - Install and configure:
   ```bash
   # macOS
   brew install rclone
   
   # Linux
   sudo apt-get install rclone  # or use snap/yum as appropriate
   ```

2. **zstd** - Compression utility:
   ```bash
   # macOS
   brew install zstd
   
   # Linux
   sudo apt-get install zstd
   ```

3. **Configure Rclone Remote:**
   Rclone can be configured in two ways:
   - **Fully Automated via `.env` (Recommended for Google Drive Service Account)**: Configure environment variables directly in your `.env` file. No interactive commands required.
   - **Interactively via CLI**: Run `rclone config` on your server to add your cloud storage provider.

## Automated Setup & Configuration

You can use the root-level `setup.sh` script to automatically install dependencies, generate random passwords, configure your rclone remote (including Google Drive Service Accounts), and schedule daily backup cron jobs.

```bash
chmod +x setup.sh
./setup.sh
```

## Usage

The backup script (`backup.sh`) supports advanced command-line arguments to target specific clients, filter backup types, or execute local-only backups.

```
Usage: ./backup.sh [options] [rclone-remote:path]

Options:
  -c, --client NAME      Only backup the specified client
  -t, --type TYPE        Backup type: 'all' (default), 'database', or 'files'
  -l, --local-only       Skip uploading to rclone remote
  -h, --help             Display this help message
```

### Examples

**1. Run full backup for all clients and upload to remote:**
```bash
./backup.sh gdrive:Backups/sahajanand-server
```
*(If `RCLONE_REMOTE_PATH` is configured in `.env`, you can simply run `./backup.sh` and it will automatically upload there).*

**2. Local-only backup (no remote upload):**
```bash
./backup.sh --local-only
```

**3. Backup only a specific client's database and upload:**
```bash
./backup.sh --client client1 --type database
```

**4. Backup only a specific client's files (directories):**
```bash
./backup.sh --client client1 --type files
```

## Google Drive Service Account (Headless Server Setup)

Google Drive standard OAuth requires a web browser to authorize, which is difficult on headless VPS servers. Using a Google Cloud **Service Account** is highly recommended because it is fully automated, non-interactive, and doesn't expire.

### Configuration Steps:
1. Go to the [Google Cloud Console](https://console.cloud.google.com).
2. Create a project and enable the **Google Drive API**.
3. Navigate to **IAM & Admin -> Service Accounts** and create a Service Account.
4. Select the created Service Account, click **Keys -> Add Key -> Create new key**, select **JSON**, and download the file.
5. Share the target Google Drive folder with the Service Account email address (giving it Editor permissions).
6. Place the downloaded JSON file as `rclone-gdrive-sa.json` in the root of this project.
7. Configure/uncomment the following in your `.env` file:

```env
RCLONE_REMOTE_PATH=gdrive:Backups/sahajanand-server
RCLONE_CONFIG_GDRIVE_TYPE=drive
RCLONE_CONFIG_GDRIVE_SCOPE=drive
RCLONE_CONFIG_GDRIVE_SERVICE_ACCOUNT_FILE=/var/www/project/rclone-gdrive-sa.json
```

> [!IMPORTANT]
> The path `/var/www/project/rclone-gdrive-sa.json` is mapped for the Docker Web UI container. When running backups on the host VPS (e.g. via cron), the script automatically translates this container path to the host absolute path. You don't need to change anything!

## Backup Structure

The script creates separate backups for each client:

### On Remote Storage:

```
rclone-remote:path/
├── client1/
│   ├── database/
│   │   ├── client1_db_20260612_120000.sql.zst
│   │   └── client1_db_20260613_120000.sql.zst
│   └── files/
│       ├── client1_files_20260612_120000.tar.zst
│       └── client1_files_20260613_120000.tar.zst
```

### What Gets Backed Up

**MySQL Databases:**
- Each client's database (`{client_name}_db`)
- Includes all tables, routines, triggers
- Compressed with zstd

**Client Files:**
- All files in the client directory
- SQLite databases (in `database/` subdirectory)
- Application code and configuration
- Excludes: logs, pid files, node_modules, .git, .env files

## Compression

Backups are compressed using **zstd** at compression level 10 (maximum compression):
- Faster than gzip with better compression ratios
- Excellent for database dumps and text files
- Decompress with: `zstd -d file.sql.zst`

## Restore

### Restore MySQL Database

```bash
# Decompress
zstd -d client1_db_20260612_120000.sql.zst

# Restore
docker exec -i mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" < client1_db_20260612_120000.sql
```

### Restore Client Files

```bash
# Download from rclone
rclone copy gdrive:Backups/sahajanand-server/client1/files/client1_files_20260612_120000.tar.zst ./

# Decompress
zstd -d client1_files_20260612_120000.tar.zst

# Extract
tar -xf client1_files_20260612_120000.tar -C clients/
```

## Automation

### Cron Job (Daily Backup)

The easiest way to schedule backups is using the `setup.sh` installer, which sets up the cron job automatically. Alternatively, add this to your crontab (`crontab -e`):

```bash
# Daily backup at 2 AM
0 2 * * * /bin/bash /path/to/sahajanand-server/backup.sh >> /path/to/sahajanand-server/logs/backup.log 2>&1
```

*(Note: The backup script will automatically load the environment variables from the `.env` file in the same directory and upload to your configured remote).*

### Systemd Timer (Linux)

Create `/etc/systemd/system/sahajanand-backup.service`:

```ini
[Unit]
Description=Sahajanand Server Backup
After=docker.service

[Service]
Type=oneshot
ExecStart=/path/to/sahajanand-server/backup.sh myremote:backups/sahajanand-server
User=your-user
```

Create `/etc/systemd/system/sahajanand-backup.timer`:

```ini
[Unit]
Description=Daily Sahajanand Server Backup
Requires=sahajanand-backup.service

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:
```bash
sudo systemctl enable sahajanand-backup.timer
sudo systemctl start sahajanand-backup.timer
```

### Launchd (macOS)

Create `~/Library/LaunchAgents/com.sahajanand.backup.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.sahajanand.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/sahajanand-server/backup.sh</string>
        <string>myremote:backups/sahajanand-server</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/var/log/sahajanand-backup.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/sahajanand-backup.error.log</string>
</dict>
</plist>
```

Load:
```bash
launchctl load ~/Library/LaunchAgents/com.sahajanand.backup.plist
```

## Environment Variables

- `BACKUP_DIR` - Local backup directory (default: `/tmp/sahajanand-backups`)
  ```bash
  BACKUP_DIR=/var/backups/sahajanand ./backup.sh myremote:backups/sahajanand-server
  ```

## Cleanup

The script automatically:
- Removes uncompressed files after compression
- Deletes local backups older than 7 days

To manually clean up remote backups (e.g., keep only last 30 days):

```bash
# List old backups
rclone lsf myremote:backups/sahajanand-server/client1/database/ | sort

# Delete backups older than 30 days (example with find, requires rclone mount)
# Or use rclone's built-in features if available
```

## Troubleshooting

### MySQL Container Not Running

If MySQL container is not running, database backups will be skipped:
```
[WARN] MySQL container is not running. Database backups will be skipped.
```

Start MySQL container:
```bash
docker-compose up -d mysql
```

### rclone Remote Not Found

Configure a remote first:
```bash
rclone config
```

### Permission Denied

Ensure the script is executable:
```bash
chmod +x backup.sh
```

### Out of Disk Space

The script uses `/tmp` by default. For large backups, set a custom directory:
```bash
BACKUP_DIR=/path/to/large/disk ./backup.sh myremote:backups/sahajanand-server
```

## Security Notes

1. **Credentials**: MySQL root password is loaded from `.env` file. Ensure `.env` has proper permissions (`chmod 600 .env`)

2. **Backup Files**: Backup files contain sensitive data. Ensure rclone remote is properly secured with encryption if needed.

3. **Client .env Files**: Client `.env` files are excluded from backups by default for security. Add them manually if needed.

## Testing

Test the backup script locally first:

```bash
# Dry run - local backup only
./backup.sh

# Check backup files
ls -lh /tmp/sahajanand-backups/*/

# Test rclone upload
./backup.sh myremote:backups/test
```

## Support

For issues or questions, check:
- Script output for error messages
- Docker logs: `docker logs mysql`
- rclone documentation: https://rclone.org/docs/

