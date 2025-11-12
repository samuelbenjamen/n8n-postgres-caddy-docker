#!/bin/bash
set -euo pipefail

# --- 1. Cleanup/Removal of Existing Docker Installations ---
echo "🧹 Cleaning up any existing Docker installations..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo rm -rf /var/lib/docker
sudo rm -f /usr/local/bin/docker-compose
sudo rm -f /usr/bin/docker-compose
sudo apt-get autoremove -y

# --- 2. Installation of Docker Engine and Docker Compose Plugin ---
echo "🐳 Installing Docker Engine and Docker Compose plugin..."
# Add Docker's official GPG key
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Add Docker repository to Apt sources
echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
# Install Docker and Compose Plugin
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- 3. Firewall Configuration (UFW) ---
echo "🔥 Setting up UFW firewall (installing if not present)..."
sudo apt-get install -y ufw || true
sudo ufw enable || true # Enable if not already enabled

# Open standard ports for HTTP/HTTPS and the n8n testing port (5678)
sudo ufw allow 80/tcp comment 'HTTP for Caddy ACME challenges'
sudo ufw allow 443/tcp comment 'HTTPS for Caddy'
sudo ufw allow 5678/tcp comment 'n8n host port for local/IP testing'
sudo ufw status verbose

# --- 4. Add User to docker Group ---
echo "👤 Adding current user to the 'docker' group..."
sudo usermod -aG docker "$USER"

echo "✅ Server preparation complete."
echo "❗️ IMPORTANT: Please LOG OUT and log back in for the 'docker' group change to take effect."
echo "Next, customize .env.example and rename it to .env, set the DOMAIN_NAME, and run 02_deploy_stack.sh."
