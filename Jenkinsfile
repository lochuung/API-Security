pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'simple-security'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        REMOTE_SERVER = 'your-server.com'
        REMOTE_USER = 'deploy'
        DOCKER_REGISTRY = 'your-registry.com'
        DOCKER_CREDENTIALS = 'docker-credentials-id'
        SSH_CREDENTIALS = 'ssh-credentials-id'
        ENV_FILE = '.env.prod'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Test') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-17-alpine'
                    args '-v $HOME/.m2:/root/.m2'
                }
            }
            steps {
                sh 'mvn clean verify'
            }
            post {
                success {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-17-alpine'
                    args '-v $HOME/.m2:/root/.m2'
                }
            }
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}")
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS}", passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                    sh """
                        docker login ${DOCKER_REGISTRY} -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD}
                        docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${DOCKER_TAG}
                    """
                }
            }
        }

        stage('Deploy to Production') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: "${SSH_CREDENTIALS}", keyFileVariable: 'SSH_KEY')]) {
                    script {
                        // Copy deployment files to remote server
                        sh """
                            scp -i ${SSH_KEY} docker-compose.prod.yml ${ENV_FILE} ${REMOTE_USER}@${REMOTE_SERVER}:/opt/deployment/
                            ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_SERVER} """

                        // Update the image tag in docker-compose file
                        sh """
                            ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_SERVER} 'cd /opt/deployment && \
                            sed -i "s/\\${APP_VERSION:-latest}/${DOCKER_TAG}/" docker-compose.prod.yml && \
                            docker-compose -f docker-compose.prod.yml pull && \
                            docker-compose -f docker-compose.prod.yml up -d'
                        """

                        // Health check
                        sh """
                            ssh -i ${SSH_KEY} ${REMOTE_USER}@${REMOTE_SERVER} 'for i in \$(seq 1 12); do \
                                if curl -f http://localhost:8080/actuator/health; then \
                                    echo "Application is healthy"; \
                                    exit 0; \
                                fi; \
                                echo "Waiting for application to be healthy..."; \
                                sleep 10; \
                            done; \
                            echo "Application failed to become healthy"; \
                            exit 1'
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            slackSend(
                color: 'good',
                message: "Deployment successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: "Deployment failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
            )
        }
    }
}
