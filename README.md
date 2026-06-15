
### Dashboards
Leveraging the prometheus metrics and displaying them in a minigfulway in a grafana dashboard you can find [here](http://localhost:3001/d/member_dashboard)
Here are the metrics:
- [API metrics of immich](http://localhost:8081/metrics)
- [Microservice metrics of immich](http://localhost:8082/metrics)
- [Prometheus itself](http://localhost:9090/metrics)
- [Node exporter](http://localhost:9100/metrics)
- [Grafana](http://localhost:3001)

### User Bootstrap Script for Keycloak

I have created a PowerShell script to automate the creation of the `Admin` user in the `selfHosting` realm and assign the required `immich_admin` role.

#### What the script does:
1.  **Authenticates** with the Keycloak Admin CLI inside the container.
2.  **Creates the user** `Admin` with email `admin@admin.ch`.
3.  **Sets the password** to `Test1234$` and marks it as permanent (no change required on first login).
4.  **Assigns the client role** `immich_admin` from the `immich` client to the user.

#### How to run it:
Ensure your Docker containers are running (`docker compose up -d`), then run the following commands in your terminal:
Note: It can take a minute for the keycloak container to be ready.

```powershell
# 1. Create the admin in Keycloak
.\bootstrap-keycloak-user.ps1

# 2. Initialize the admin in Immich (required if first start)
.\bootstrap-immich-admin.ps1
```

### Member Onboarding Script
I have also provided a script for interactive member onboarding. This script will prompt you for the new member's details and set up their account in Keycloak with the appropriate roles.

#### Password Policies:
The onboarding script enforces the following password policies for custom passwords:
- **Minimum 8 characters**
- **Minimum 1 digit**
- **Minimum 1 special character**
- **Minimum 1 capital letter**
- **Cannot contain the username or email address**

The host also has the option to set a standard password (**Community2026!**) for new members.

#### How to run it:
```powershell
.\onboard-member.ps1
```
Now the script will prompt you for the new member's details. And you can distribute the new member's credentials to them.

#### Stepping up the Onboarding Experience
For a better onboarding experience, I recommend adding an email provider to Immich or Keycloak for automatic credential distribution when onboarding a new member.

### Deploying to Phala Cloud

Phala Cloud provides a robust environment for hosting decentralized applications. To deploy this setup to Phala Cloud using the CLI:

1.  **Prepare your Environment**: 
    - Ensure you have your `.env` file configured.
    - Set the `DOCKER_REGISTRY` value in your `.env` file (the `deploy-phala.ps1` script will automatically load it).
      - **IMPORTANT**: Include the registry hostname.
      - For **GitHub Container Registry**: `ghcr.io/youruser`
      - For **Docker Hub**: `docker.io/youruser`
      - **Note: Do not use placeholders like "SelfHost" or just your username.**
    - Ensure you are logged into your registry. For example: `docker login ghcr.io` or `docker login docker.io`.
    - **Note on Permissions**: If you see `insufficient_scope` or `push access denied`, especially with private repositories:
        - For **GHCR**: Ensure your PAT has `write:packages` and `repo` scopes.
        - For **Docker Hub**: Ensure your user has write access to the repository.
        - Ensure the repository name is correct (Docker sometimes creates repositories automatically on first push, but some registries require manual creation).
2.  **Authenticate**: Log in to Phala Cloud using the CLI:
    ```powershell
    phala login
    ```
3.  **Deploy**: Use the provided deployment script. This will build custom images with your configurations, push them to your registry, and then deploy to Phala Cloud:
    ```powershell
    .\deploy-phala.ps1
    ```
    This script uses `phala deploy` with `immich-compose.phala.yml` and handles the necessary environment variables and pre-launch scripts.

4.  **Run Bootstrap Scripts**: Once the containers are healthy, execute the bootstrap scripts to initialize the admin users:
    ```powershell
    .\bootstrap-keycloak-user.ps1
    .\bootstrap-immich-admin.ps1
    ```
5.  **Access your Instance**: Your Immich instance will be available at the external domain provided by Phala Cloud (e.g., `https://<cvm-id>-2283.<gateway-domain>`).

#### Troubleshooting Keycloak Redirects
If Keycloak redirects you to an internal address (like `http://keycloak/...`), ensure that `KC_HOSTNAME_STRICT` is set to `false` in your compose file (this is the default in our Phala-optimized version).

**Important for OIDC Login**:
To make "Login with Keycloak" work in Immich, you must set the `IMMICH_OIDC_ISSUER_URL` in your `.env` file to the **public** URL of your Keycloak instance.
1. Find your Keycloak URL (it usually ends in `-8443.dstack...`).
2. Add the following to your `.env`:
   ```
   IMMICH_OIDC_ISSUER_URL=https://<your-app-id>-8443.<gateway-domain>/auth/realms/selfHosting
   ```
3. Redeploy with `.\deploy-phala.ps1`.