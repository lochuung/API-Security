#!/bin/bash

# Strict error handling
set -euo pipefail

# Load environment variables
source ../.env.prod

# Configuration
BACKUP_DIR="/opt/backups"
REMOTE_BACKUP_DIR="s3://your-bucket/backups"  # Configure your remote storage
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="security_backup_${TIMESTAMP}"
LOG_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.log"

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Error handling
error_handler() {
    log "Error occurred in backup script at line $1"
    # Send notification (customize as needed)
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"Backup failed! Check ${LOG_FILE}\"}" "${SLACK_WEBHOOK_URL}"
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# Start backup process
log "Starting backup process..."

# Create temporary directory for this backup
TEMP_DIR=$(mktemp -d)
log "Created temporary directory: ${TEMP_DIR}"

# Backup PostgreSQL
log "Backing up PostgreSQL database..."
PGPASSWORD="${DB_PASSWORD}" pg_dump \
    -h localhost \
    -U "${DB_USER}" \
    -d security_db \
    -F c \
    -b \
    -v \
    -f "${TEMP_DIR}/postgres_dump.backup" 2>> "${LOG_FILE}"

# Backup MongoDB
log "Backing up MongoDB..."
mongodump \
    --uri="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@localhost:27017/security_logs?authSource=admin" \
    --out="${TEMP_DIR}/mongo_dump" \
    --gzip 2>> "${LOG_FILE}"

# Backup Redis
log "Backing up Redis..."
redis-cli -a "${REDIS_PASSWORD}" SAVE
cp /data/dump.rdb "${TEMP_DIR}/redis_dump.rdb"

# Create archive
log "Creating backup archive..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" -C "${TEMP_DIR}" . 2>> "${LOG_FILE}"

# Verify backup integrity
log "Verifying backup integrity..."
if ! tar -tzf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" > /dev/null; then
    log "Backup verification failed!"
    exit 1
fi

# Upload to remote storage (if configured)
if command -v aws &> /dev/null; then
    log "Uploading backup to remote storage..."
    aws s3 cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "${REMOTE_BACKUP_DIR}/" \
        --storage-class STANDARD_IA
fi

# Cleanup old backups (keep last 7 days locally)
log "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "security_backup_*.tar.gz" -mtime +7 -delete
find "${BACKUP_DIR}" -name "backup_*.log" -mtime +7 -delete

# Cleanup temporary directory
log "Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"

# Calculate backup size
BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
log "Backup completed successfully! Size: ${BACKUP_SIZE}"

# Send success notification
curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"Backup completed successfully! Size: ${BACKUP_SIZE}\"}" \
    "${SLACK_WEBHOOK_URL}"

exit 0
