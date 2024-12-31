#!/bin/bash

# Exit on any error
set -e

# Load environment variables
source .env.prod

# Pull latest images
docker-compose -f docker-compose.prod.yml pull

# Deploy the stack
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d

# Wait for health checks
echo "Waiting for services to be healthy..."
sleep 30

# Verify deployment
curl -f http://localhost:8080/actuator/health || exit 1

echo "Deployment completed successfully!"
