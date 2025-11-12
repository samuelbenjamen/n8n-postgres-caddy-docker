#!/bin/bash
set -euo pipefail

ENV_FILE=".env"

# --- 1. Verify .env file existence ---
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: The configuration file '$ENV_FILE' was not found."
    echo "Please copy '.env.example' to '.env' and customize your credentials."
    exit 1
fi

# --- 2. Check for required DOMAIN_NAME environment variable ---
if [ -z "${DOMAIN_NAME:-}" ]; then
    echo "❌ Error: The DOMAIN_NAME environment variable is not set."
    echo "Caddy requires this to configure HTTPS."
    echo ""
    echo "Example usage:"
    echo "export DOMAIN_NAME=n8n.example.com"
    echo "./02_deploy_stack.sh"
    exit 1
fi

echo "✅ Environment variables and configuration checked."
echo "   Deploying for public domain: https://$DOMAIN_NAME"

# --- 3. Build and start services in detached mode (-d) ---
echo "🐳 Pulling images and deploying the n8n stack with Docker Compose..."
# Use the -f flag to specify the compose file
# Use --env-file to explicitly load the variables
# Use --build to ensure latest changes/images are used
# Use -d for detached mode
docker compose -f docker-compose.yml \
               --env-file "$ENV_FILE" \
               up -d --build

echo ""
echo "--- Deployment Complete ---"
echo ""
echo "🌐 Public Access (via Caddy/HTTPS):"
echo "   https://$DOMAIN_NAME"
echo ""
echo "🔬 Local/IP Testing Access (via port 5678):"
echo "   http://<YOUR_VM_IP_ADDRESS>:5678"
echo "   (Example: http://192.168.1.10:5678)"
echo ""
echo "Use 'docker compose down' to stop and remove containers/networks."
echo "Use 'docker compose logs -f' to view running logs."
