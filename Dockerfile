FROM eclipse-temurin:21-jdk

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone and build BetterDeob from GitHub
RUN git clone https://github.com/K13094/better-deob.git /app/better-deob && \
    cd /app/better-deob && ./gradlew build --no-daemon

# Copy scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Create data directories
RUN mkdir -p /app/data /app/output

# Environment variables (override in docker-compose)
ENV GITHUB_REPO=""
ENV GITHUB_TOKEN=""
ENV CHECK_INTERVAL_SECONDS=300

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD [ -f /app/data/hooks.json ] || exit 1

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
