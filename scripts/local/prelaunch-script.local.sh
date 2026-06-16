#!/bin/bash
echo "----------------------------------------------"
echo "Running Local Pre-Launch Script v0.0.1"
echo "----------------------------------------------"
set -e

# Function: notify host (Mocked for local)
notify_host() {
    echo "NOTIFY: $1 - $2"
}

notify_host_hoot_info() {
    notify_host "boot.progress" "$1"
}

notify_host_hoot_error() {
    notify_host "boot.error" "$1"
}

# Function: Perform Docker cleanup
perform_cleanup() {
    echo "Pruning unused images"
    docker image prune -af
    echo "Pruning unused volumes"
    docker volume prune -f
    notify_host_hoot_info "docker cleanup completed"
}

# Function: Check Docker login status without exposing credentials
check_docker_login() {
    local registry="$1"

    # When registry is specified, check auth entry for that registry in Docker config
    if [[ -n "$registry" ]]; then
        local docker_config_path="${DOCKER_CONFIG:-$HOME/.docker}/config.json"
        if [[ -f "$docker_config_path" ]] && grep -q "$registry" "$docker_config_path"; then
            return 0
        else
            return 1
        fi
    fi

    # Fallback check when no explicit registry is provided
    if docker info 2>/dev/null | grep -q "Username"; then
        return 0
    else
        return 1
    fi
}

# Main logic starts here
echo "Starting login process..."

# Check if Docker credentials exist (from .env or environment)
if [[ -n "$DSTACK_DOCKER_USERNAME" && -n "$DSTACK_DOCKER_PASSWORD" ]]; then
    echo "Docker credentials found"
    DOCKER_REGISTRY_TARGET="${DSTACK_DOCKER_REGISTRY:-docker.io}"
    echo "Target Docker registry: $DOCKER_REGISTRY_TARGET"

    # Check if already logged in
    if check_docker_login "$DSTACK_DOCKER_REGISTRY"; then
        echo "Already logged in to Docker registry: $DOCKER_REGISTRY_TARGET"
    else
        echo "Logging in to Docker registry: $DOCKER_REGISTRY_TARGET"
        # Login without exposing password in process list
        if [[ -n "$DSTACK_DOCKER_REGISTRY" ]]; then
            echo "$DSTACK_DOCKER_PASSWORD" | docker login -u "$DSTACK_DOCKER_USERNAME" --password-stdin "$DSTACK_DOCKER_REGISTRY"
        else
            echo "$DSTACK_DOCKER_PASSWORD" | docker login -u "$DSTACK_DOCKER_USERNAME" --password-stdin
        fi

        if [ $? -eq 0 ]; then
            echo "Docker login successful: $DOCKER_REGISTRY_TARGET"
        else
            echo "Docker login failed: $DOCKER_REGISTRY_TARGET"
            notify_host_hoot_error "docker login failed"
            exit 1
        fi
    fi
fi

perform_cleanup

#
# Pull latest images from immich-compose.local.yml
#
echo "Images before pull:"
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} ({{.CreatedSince}})'

echo "Pulling latest images from immich-compose.local.yml..."
if docker compose -f immich-compose.local.yml pull; then
    echo "docker compose pull completed"
    notify_host_hoot_info "docker compose pull completed"
else
    echo "WARNING: docker compose pull failed; continuing with existing images"
    notify_host_hoot_info "docker compose pull failed; using existing images"
fi

echo "Images after pull:"
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} ({{.CreatedSince}})'

#
# Local domain setup
#
export DSTACK_APP_DOMAIN="localhost"
echo "Local App Domain: $DSTACK_APP_DOMAIN"

#
# Generate certificates for Keycloak (optional for local but kept for compatibility if needed)
#
if [[ -n "$DSTACK_APP_DOMAIN" ]]; then
    echo "Generating certificates for Keycloak..."
    mkdir -p certs
    if [[ ! -f "certs/server.crt" ]]; then
        CERT_CN="$DSTACK_APP_DOMAIN"
        openssl req -x509 -newkey rsa:4096 -nodes -sha256 -keyout certs/server.key -out certs/server.crt -subj "/CN=$CERT_CN" -days 365
        echo "Certificates generated for CN=$CERT_CN"
    else
        echo "Certificates already exist, skipping generation"
    fi
    chmod 644 certs/server.key certs/server.crt
else
    echo "Skipping certificate generation: DSTACK_APP_DOMAIN not set"
fi

echo "----------------------------------------------"
echo "Script execution completed"
echo "----------------------------------------------"
