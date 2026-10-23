#!/usr/bin/env bash
# Reusable equivalent of the Jenkins Freestyle Nginx deployment step.
# Target: Docker Engine on the Jenkins SSH agent (not the controller).
# WARNING: removes/replaces only a container named 'jenkins-nginx'.
set -Eeuo pipefail

IMAGE='nginx:1.30.6'
CONTAINER='jenkins-nginx'
HOST_PORT='8081'

echo 'Deploying Nginx on Jenkins agent...'
echo "Image: ${IMAGE} | Container: ${CONTAINER} | Host port: ${HOST_PORT}"

docker pull "$IMAGE"

if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
    echo "Removing previous container ${CONTAINER}"
    docker container rm --force "$CONTAINER"
fi

docker run -d \
    --name "$CONTAINER" \
    --publish "${HOST_PORT}:80" \
    "$IMAGE"

docker ps --filter "name=^/${CONTAINER}$"

# Retry because process start/HTTP readiness can lag container creation.
curl --fail --silent --show-error --head \
    --retry 6 --retry-delay 2 --retry-connrefused \
    "http://127.0.0.1:${HOST_PORT}/"

echo 'Nginx deployment completed and HTTP endpoint responded.'
