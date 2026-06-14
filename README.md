[API metrics of immich](http://localhost:8081/metrics)
[Microservice metrics of immich](http://localhost:8082/metrics)
[prometheus](http://localhost:9090/metrics)
[node exporter](http://localhost:9100/metrics)
[grafana](http://localhost:3001)
[member dashboard](http://localhost:3001/d/member_dashboard)


### User Bootstrap Script for Keycloak

I have created a PowerShell script to automate the creation of the `Admin` user in the `selfHosting` realm and assign the required `immich_admin` role.

#### What the script does:
1.  **Authenticates** with the Keycloak Admin CLI inside the container.
2.  **Creates the user** `Admin` with email `admin@admin.ch`.
3.  **Sets the password** to `Test1234$` and marks it as permanent (no change required on first login).
4.  **Assigns the client role** `immich_admin` from the `immich` client to the user.

#### How to run it:
Ensure your Docker containers are running (`docker compose up -d`), then run the following command in your terminal:

```powershell
.\bootstrap-keycloak-user.ps1
```

### Final OIDC Connectivity Check
Once the script finishes, you can go to your Immich login page, click "Login with Keycloak", and use:
- **Username**: Admin
- **Password**: Test1234$