pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'your-registry.com'
        IMAGE_NAME = 'simple-security'
        DOCKER_CREDS = credentials('docker-registry-credentials')
        SONAR_TOKEN = credentials('sonar-token')
        APP_VERSION = "1.0.${BUILD_NUMBER}"
        DEV_SERVER = credentials('dev-server-ssh')
        PROD_SERVER = credentials('prod-server-ssh')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh './mvnw clean test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh './mvnw sonar:sonar -Dsonar.login=$SONAR_TOKEN'
                }
            }
        }
        
        stage('Build Application') {
            steps {
                sh './mvnw clean package -DskipTests'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME}:${APP_VERSION}")
                    docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME}:latest")
                }
            }
        }
        
        stage('Push Docker Image') {
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", 'docker-registry-credentials') {
                        docker.image("${DOCKER_REGISTRY}/${IMAGE_NAME}:${APP_VERSION}").push()
                        docker.image("${DOCKER_REGISTRY}/${IMAGE_NAME}:latest").push()
                    }
                }
            }
        }
        
        stage('Deploy to Development') {
            when { branch 'develop' }
            steps {
                script {
                    sshagent(credentials: ['dev-server-ssh']) {
                        sh """
                            # Ensure deployment directory exists
                            ssh -o StrictHostKeyChecking=no ${DEV_SERVER_USR}@${DEV_SERVER_PSW} 'mkdir -p ~/deployments'
                            
                            # Copy deployment files
                            scp docker-compose.yml .env.dev ${DEV_SERVER_USR}@${DEV_SERVER_PSW}:~/deployments/
                            
                            # Execute deployment
                            ssh -o StrictHostKeyChecking=no ${DEV_SERVER_USR}@${DEV_SERVER_PSW} '''
                                cd ~/deployments
                                echo "APP_VERSION=${APP_VERSION}" > .env
                                docker login ${DOCKER_REGISTRY} -u ${DOCKER_CREDS_USR} -p ${DOCKER_CREDS_PSW}
                                docker-compose pull
                                docker-compose --env-file .env.dev up -d
                                docker image prune -f
                            '''
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            when { branch 'main' }
            steps {
                script {
                    sshagent(credentials: ['prod-server-ssh']) {
                        sh """
                            # Ensure deployment directory exists
                            ssh -o StrictHostKeyChecking=no ${PROD_SERVER_USR}@${PROD_SERVER_PSW} 'mkdir -p /opt/deployments'
                            
                            # Copy deployment files
                            scp docker-compose.prod.yml .env.prod ${PROD_SERVER_USR}@${PROD_SERVER_PSW}:/opt/deployments/
                            
                            # Execute deployment
                            ssh -o StrictHostKeyChecking=no ${PROD_SERVER_USR}@${PROD_SERVER_PSW} '''
                                cd /opt/deployments
                                echo "APP_VERSION=${APP_VERSION}" > .env
                                docker login ${DOCKER_REGISTRY} -u ${DOCKER_CREDS_USR} -p ${DOCKER_CREDS_PSW}
                                docker-compose -f docker-compose.prod.yml pull
                                docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
                                docker image prune -f
                                
                                # Wait for health checks
                                echo "Waiting for application to be healthy..."
                                timeout=300
                                while [ $timeout -gt 0 ]; do
                                    if curl -s http://localhost:8080/actuator/health | grep "UP"; then
                                        echo "Application is healthy"
                                        exit 0
                                    fi
                                    sleep 5
                                    timeout=$((timeout-5))
                                done
                                echo "Health check timeout"
                                exit 1
                            '''
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
            slackSend(color: 'good', message: "Build Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
        failure {
            slackSend(color: 'danger', message: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
    }
}
