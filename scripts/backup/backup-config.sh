#!/bin/bash

# Backup storage settings
BACKUP_DIR="/opt/backups"
RETENTION_DAYS=7

# PostgreSQL settings
POSTGRES_CONTAINER="security_postgres"
PG_DB="security_db"
PG_USER="secuser_prod"

# MongoDB settings
MONGO_CONTAINER="security_mongodb"
MONGO_DB="security_logs"
MONGO_USER="mongoadmin_prod"

# Redis settings
REDIS_CONTAINER="security_redis"

# Load environment variables
source /opt/deployment/.env.prod

# Create backup directories if they don't exist
mkdir -p "${BACKUP_DIR}/postgres"
mkdir -p "${BACKUP_DIR}/mongodb"
mkdir -p "${BACKUP_DIR}/redis"

# Set timestamp format
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
