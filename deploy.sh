#!/bin/bash
set -e

echo ">>> Updating project files..."

echo ">>> Logging in to GHCR..."
echo $GHCR_PAT | docker login ghcr.io -u astle286 --password-stdin

echo ">>> Pulling latest image..."
docker pull ghcr.io/astle286/devops-helper:latest

echo ">>> Restarting containers..."

docker-compose down
docker-compose up -d

echo ">>> Deployment complete! Running latest"