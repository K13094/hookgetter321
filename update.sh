#!/bin/bash
# Run this script to update the service to the latest version
cd "$(dirname "$0")"
git pull
docker-compose down
docker-compose up -d --build --force-recreate
echo "Update complete!"
