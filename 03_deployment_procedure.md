# 🚀 n8n Production Deployment Procedure

This guide provides the full procedure to deploy the n8n stack on a clean Ubuntu 25.04 VM using Docker Compose, PostgreSQL, and Caddy.

## Prerequisites

1.  A clean **Ubuntu 25.04** Virtual Machine or dedicated server.
2.  A **Domain Name** (e.g., `n8n.example.com`) pointed via an A-record to your server's public IP address.

## Step 1: Initialize Repository and Configuration

1.  **Clone the Repository:**
    Log in to your server and clone the files:
    ```bash
    git clone [https://github.com/your-username/n8n-postgres-caddy-docker.git](https://github.com/your-username/n8n-postgres-caddy-docker.git)
    cd n8n-postgres-caddy-docker
    ```

2.  **Customize Environment Variables:**
    Copy the example file and edit it to set your credentials and preferred timezone. **Use strong, random passwords.**
    ```bash
    cp .env.example .env
    nano .env 
    ```
    *Ensure `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `N8N_BASIC_AUTH_PASSWORD` are customized.*

## Step 2: Prepare the Server (Run `01_prepare_server.sh`)

This script installs Docker, Docker Compose, and configures the firewall.

```bash
chmod +x 01_prepare_server.sh
./01_prepare_server.sh
