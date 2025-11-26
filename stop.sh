#!/bin/bash
set -e

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Please copy the .env.example file to .env and fill in the values."
    exit 1
fi

echo "================================================================="
echo "Stopping all services..."
echo "================================================================="
docker compose stop
echo ""

