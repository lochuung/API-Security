#!/bin/bash

# Load backup configuration
source "$(dirname "$0")/backup-config.sh"

# Restore PostgreSQL
restore_postgres() {
    local backup_file=$1
    if [ -z "$backup_file" ]; then
        backup_file=$(ls -t "${BACKUP_DIR}/postgres/"*.sql.gz | head -1)
    fi
    
    echo "Restoring PostgreSQL from ${backup_file}..."
    gunzip -c "${backup_file}" | docker exec -i ${POSTGRES_CONTAINER} psql -U ${PG_USER} ${PG_DB}
}

# Restore MongoDB
restore_mongodb() {
    local backup_file=$1
    if [ -z "$backup_file" ]; then
        backup_file=$(ls -t "${BACKUP_DIR}/mongodb/"*.tar.gz | head -1)
    fi
    
    echo "Restoring MongoDB from ${backup_file}..."
    tar xzf "${backup_file}"
    docker cp backup/${MONGO_DB} ${MONGO_CONTAINER}:/tmp/
    docker exec ${MONGO_CONTAINER} mongorestore \
        --username ${MONGO_USER} \
        --password ${MONGO_PASSWORD} \
        --authenticationDatabase admin \
        --db ${MONGO_DB} \
        /tmp/${MONGO_DB}
    rm -rf backup
}

# Restore Redis
restore_redis() {
    local backup_file=$1
    if [ -z "$backup_file" ]; then
        backup_file=$(ls -t "${BACKUP_DIR}/redis/"*.rdb | head -1)
    fi
    
    echo "Restoring Redis from ${backup_file}..."
    docker cp "${backup_file}" ${REDIS_CONTAINER}:/data/dump.rdb
    docker restart ${REDIS_CONTAINER}
}

# Main restore process
main() {
    if [ "$#" -eq 0]; then
        echo "No specific backup files provided. Using most recent backups."
        restore_postgres
        restore_mongodb
        restore_redis
    else
        case "$1" in
            "postgres") restore_postgres "$2" ;;
            "mongodb") restore_mongodb "$2" ;;
            "redis") restore_redis "$2" ;;
            *) echo "Invalid database type. Use: postgres, mongodb, or redis" ;;
        esac
    fi
}

main "$@" 2>&1 | tee "${BACKUP_DIR}/restore_${TIMESTAMP}.log"
