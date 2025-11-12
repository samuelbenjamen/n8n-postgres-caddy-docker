# n8n Production Stack: PostgreSQL, Caddy, Docker Compose

This repository provides a robust, production-ready setup for n8n using Docker Compose. It leverages PostgreSQL for persistent data storage and Caddy as a reverse proxy for automatic HTTPS (via Let's Encrypt).

## 🚀 Setup & Deployment

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/your-username/n8n-postgres-caddy-docker.git](https://github.com/your-username/n8n-postgres-caddy-docker.git)
    cd n8n-postgres-caddy-docker
    ```

2.  **Prepare the Ubuntu Server:**
    Run the preparation script to install Docker, Docker Compose, and configure the firewall (UFW).
    ```bash
    chmod +x 01_prepare_server.sh
    ./01_prepare_server.sh
    ```
    ***NOTE: You must log out and log back in after this step!***

3.  **Configure Environment:**
    Copy the example file and customize your sensitive variables:
    ```bash
    cp .env.example .env
    # Edit the .env file with strong passwords and timezone
    nano .env
    ```

4.  **Set Public Domain and Deploy:**
    Set your public domain as an environment variable (used by Caddy) and run the deployment script.
    ```bash
    export DOMAIN_NAME=your.public.domain.com
    chmod +x 02_deploy_stack.sh
    ./02_deploy_stack.sh
    ```

## 🌐 Access

* **Public Access (HTTPS):** `https://your.public.domain.com`
* **Local/IP Testing (HTTP):** `http://<VM_IP_ADDRESS>:5678`

## 🛠️ Management Commands

| Command | Action |
| :--- | :--- |
| `docker compose ps` | View running container status. |
| `docker compose logs -f` | View real-time logs for all services. |
| `docker compose down` | Stop and remove the containers and network. |
| `docker compose up -d` | Restart the stack. |
