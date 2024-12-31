pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'your-registry.com'
        IMAGE_NAME = 'simple-security'
        DOCKER_CREDS = credentials('docker-registry-credentials')
        SONAR_TOKEN = credentials('sonar-token')
        APP_VERSION = "1.0.${BUILD_NUMBER}"
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
                    sh """
                        export APP_VERSION=${APP_VERSION}
                        docker-compose -f docker-compose.prod.yml --env-file .env.prod down
                        docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d
                    """
                }
            }
        }
        
        stage('Deploy to Production') {
            when { branch 'main' }
            environment {
                PROD_SERVER = credentials('prod-server-ssh')
            }
            steps {
                script {
                    sh """
                        scp docker-compose.prod.yml .env.prod ${PROD_SERVER}:/opt/deployments/
                        ssh ${PROD_SERVER} 'cd /opt/deployments && \
                        export APP_VERSION=${APP_VERSION} && \
                        docker-compose -f docker-compose.prod.yml --env-file .env.prod down && \
                        docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d'
                    """
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
