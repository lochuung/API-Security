# Build stage
FROM maven:3.9-eclipse-temurin-17-alpine AS builder
WORKDIR /build
# Copy only pom.xml first to cache dependencies
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source code and build
COPY src src
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:17-jre-alpine

# Add non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Create necessary directories
RUN mkdir -p /app/config /var/log/security-app /app/logs \
    && chown -R appuser:appgroup /app /var/log/security-app

# Set working directory
WORKDIR /app

# Copy JAR from builder stage
COPY --from=builder /build/target/*.jar app.jar

# Copy configuration files if needed
COPY --chown=appuser:appgroup src/main/resources/application-prod.yml config/
COPY --chown=appuser:appgroup src/main/resources/logback-spring.xml config/

# Install curl for healthcheck
RUN apk add --no-cache curl

# Environment variables
ENV SPRING_CONFIG_LOCATION=file:/app/config/

# Expose port
EXPOSE 8080

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Start application with proper memory settings
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar --spring.profiles.active=prod"]
