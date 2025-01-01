#!/bin/bash

# Load backup configuration
source "$(dirname "$0")/backup-config.sh"

# Backup PostgreSQL
backup_postgres() {
    echo "Starting PostgreSQL backup..."
    docker exec ${POSTGRES_CONTAINER} pg_dump -U ${PG_USER} ${PG_DB} | gzip > "${BACKUP_DIR}/postgres/postgres_${TIMESTAMP}.sql.gz"
    if [ $? -eq 0 ]; then
        echo "PostgreSQL backup completed successfully"
    else
        echo "PostgreSQL backup failed"
        return 1
    fi
}

# Backup MongoDB
backup_mongodb() {
    echo "Starting MongoDB backup..."
    docker exec ${MONGO_CONTAINER} mongodump \
        --db ${MONGO_DB} \
        --username ${MONGO_USER} \
        --password ${MONGO_PASSWORD} \
        --authenticationDatabase admin \
        --out /tmp/backup
    
    docker cp ${MONGO_CONTAINER}:/tmp/backup .
    tar czf "${BACKUP_DIR}/mongodb/mongodb_${TIMESTAMP}.tar.gz" backup/${MONGO_DB}
    rm -rf backup
    docker exec ${MONGO_CONTAINER} rm -rf /tmp/backup

    if [ $? -eq 0 ]; then
        echo "MongoDB backup completed successfully"
    else
        echo "MongoDB backup failed"
        return 1
    fi
}

# Backup Redis
backup_redis() {
    echo "Starting Redis backup..."
    docker exec ${REDIS_CONTAINER} redis-cli -a "${REDIS_PASSWORD}" SAVE
    docker cp ${REDIS_CONTAINER}:/data/dump.rdb "${BACKUP_DIR}/redis/redis_${TIMESTAMP}.rdb"
    
    if [ $? -eq 0 ]; then
        echo "Redis backup completed successfully"
    else
        echo "Redis backup failed"
        return 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    find "${BACKUP_DIR}/postgres" -type f -mtime +${RETENTION_DAYS} -exec rm {} \;
    find "${BACKUP_DIR}/mongodb" -type f -mtime +${RETENTION_DAYS} -exec rm {} \;
    find "${BACKUP_DIR}/redis" -type f -mtime +${RETENTION_DAYS} -exec rm {} \;
}

# Main backup process
main() {
    echo "Starting backup process at $(date)"
    
    backup_postgres
    backup_mongodb
    backup_redis
    cleanup_old_backups
    
    echo "Backup process completed at $(date)"
}

main 2>&1 | tee "${BACKUP_DIR}/backup_${TIMESTAMP}.log"
