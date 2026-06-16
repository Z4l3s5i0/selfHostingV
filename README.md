# Immich Self-Hosting Stack

This repository provides a complete stack for self-hosting Immich with Keycloak for authentication, along with monitoring (Prometheus, Grafana).

## Directory Structure

- `docker/`: Dockerfiles and build context for custom images.
- `scripts/`: Deployment and management scripts.
  - `local/`: Scripts for local deployment.
  - `phala/`: Scripts for Phala Cloud deployment.
- `immich-compose.local.yml` and `immich-compose.phala.yml`: Docker Compose files for local and Phala environments.
- `prometheus.yml`, `grafana/`, `keycloak/`: Configuration files for services.

## Deployment Options

### 1. Local Deployment

For testing or personal use on your local machine.

#### Prerequisites
- Docker and Docker Compose installed.
- PowerShell (for running `.ps1` scripts).

#### How to deploy:
```powershell
# Run the local deployment script
./scripts/local/deploy-local.ps1
```
This script will:
1. Load environment variables from `.env`.
2. Generate self-signed certificates for `localhost`.
3. Build custom images locally.
4. Pull external images.
5. Launch the stack using `docker compose`.

**Access:**
- **Immich:** [http://localhost:2283](http://localhost:2283)
- **Keycloak:** [http://localhost:8080/auth](http://localhost:8080/auth)
- **Grafana Dashboards:** [http://localhost:3001/d/member_dashboard](http://localhost:3001/d/member_dashboard)

---

### 2. Phala Cloud Deployment

For deploying to a decentralized environment on Phala Cloud.

#### Prerequisites
- Phala CLI installed and authenticated (`phala login`).
- A Docker Registry (GHCR, Docker Hub, etc.).

#### How to deploy:
1. **Configure `.env`**: Ensure `DOCKER_REGISTRY` is set to your registry (e.g., `ghcr.io/youruser`).
2. **Deploy**:
   ```powershell
   ./scripts/phala/deploy-phala.ps1
   ```
This script will build and push custom images to your registry and then initiate the Phala deployment.


---

## Post-Deployment: User Management (local deployment only)

Once the stack is running, you need to initialize the admin users. Note that 4 accounts have been created for testing purposes (see submission).

### 1. Initial Bootstrap
Run these scripts to create the initial admin user in Keycloak and sync it with Immich:
```powershell
# Create the admin in Keycloak
./scripts/bootstrap-keycloak-user.ps1

# Initialize the admin in Immich (required if first start)
./scripts/bootstrap-immich-admin.ps1
```

### 2. Member Onboarding
Use the interactive script to add new community members:
```powershell
./scripts/onboard-member.ps1
```
The script enforces password policies and assigns appropriate roles (`immich_user` or `immich_admin`).

## Monitoring and Metrics on localhost

- **Grafana Dashboards:** [http://localhost:3001/d/member_dashboard](http://localhost:3001/d/member_dashboard)
- **Immich:** [http://localhost:2283](http://localhost:2283)
- **Keycloak:** [http://localhost:8080/auth](http://localhost:8080/auth)

## Monitoring and Metrics on phala cloud
**Access:**
- **Grafana Dashboards:** [https://d9222cfae9dab9f3d2229e8e8fa64e64a29d25ec-3001.dstack-pha-prod9.phala.network/d/member_dashboard](https://d9222cfae9dab9f3d2229e8e8fa64e64a29d25ec-3001.dstack-pha-prod9.phala.network/d/member_dashboard)
- **Immich:** [https://d9222cfae9dab9f3d2229e8e8fa64e64a29d25ec-2283.dstack-pha-prod9.phala.network](https://d9222cfae9dab9f3d2229e8e8fa64e64a29d25ec-2283.dstack-pha-prod9.phala.network)
- **Keycloak:** [https://d9222cfae9dab9f3d2229e8e8fa64e64a29d25ec-8080.dstack-pha-prod9.phala.network/auth](https://d9222cfae9dab9f3d2229e8e8fa64e64a29d25ec-8080.dstack-pha-prod9.phala.network/auth)

## License

This project is licensed under the Creative Commons Attribution 4.0 International License. See the [LICENSE](https://creativecommons.org/licenses/by/4.0/) for details.

