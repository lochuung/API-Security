#!/bin/bash

# Exit on any error
set -e

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
until $(curl --output /dev/null --silent --head --fail http://localhost:8081); do
    printf '.'
    sleep 5
done

# Get the initial admin password
JENKINS_PASSWORD=$(docker exec security_jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
echo "Jenkins initial admin password: $JENKINS_PASSWORD"

# Install suggested plugins
echo "Installing Jenkins plugins..."
docker exec security_jenkins jenkins-plugin-cli --plugins \
    git \
    workflow-aggregator \
    docker-workflow \
    pipeline-stage-view \
    blueocean \
    credentials-binding \
    docker-plugin \
    configuration-as-code \
    sonar \
    jacoco \
    junit \
    slack

# Restart Jenkins to apply plugin changes
echo "Restarting Jenkins..."
docker restart security_jenkins

echo "Jenkins setup completed! Access it at http://localhost:8081"
echo "Initial admin password: $JENKINS_PASSWORD"
