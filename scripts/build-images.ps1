# Build and Push Script for Phala Cloud Deployment
# This script builds custom Docker images with baked-in configurations
# and pushes them to your registry.

param (
    [Parameter(Mandatory=$true)]
    [string]$Registry, # e.g., "myregistry.azurecr.io" or "ghcr.io/myuser"

    [string]$Environment = "phala", # "local" or "phala"

    [switch]$Push = $true
)

$Images = @(
    @{ Name = "prometheus-custom"; Path = "docker/prometheus" },
    @{ Name = "grafana-custom"; Path = "docker/grafana" },
    @{ Name = "keycloak-custom"; Path = "docker/keycloak" },
    @{ Name = "immich-server-custom"; Path = "docker/immich-server" }
)

foreach ($Img in $Images) {
    $FullTag = "$Registry/$($Img.Name):latest"
    Write-Host "Building $FullTag..." -ForegroundColor Cyan
    
    # Check if we need to copy context files
    $RootPath = Join-Path $PSScriptRoot ".."
    if ($Img.Name -eq "prometheus-custom") {
        Copy-Item (Join-Path $RootPath "prometheus.yml") "$($Img.Path)/prometheus.yml" -Force
    } elseif ($Img.Name -eq "grafana-custom") {
        if (-Not (Test-Path "$($Img.Path)/grafana")) { New-Item -ItemType Directory -Path "$($Img.Path)/grafana" }
        Copy-Item (Join-Path $RootPath "grafana/provisioning") "$($Img.Path)/grafana/" -Recurse -Force
        # Copy environment-specific dashboard
        $DashboardDir = Join-Path "$($Img.Path)/grafana" "dashboards"
        if (-Not (Test-Path $DashboardDir)) { New-Item -ItemType Directory -Path $DashboardDir }
        $DashboardSource = Join-Path $RootPath "grafana/dashboards/member_dashboard.$Environment.json"
        if (Test-Path $DashboardSource) {
            Copy-Item $DashboardSource (Join-Path $DashboardDir "member_dashboard.json") -Force
        } else {
            Write-Error "Dashboard source not found: $DashboardSource"
            exit 1
        }
    } elseif ($Img.Name -eq "keycloak-custom") {
        if (-Not (Test-Path "$($Img.Path)/keycloak")) { New-Item -ItemType Directory -Path "$($Img.Path)/keycloak" }
        $RealmSource = Join-Path $RootPath "keycloak/realm-export.$Environment.json"
        if (-Not (Test-Path $RealmSource)) {
            Write-Error "Realm source not found: $RealmSource"
            exit 1
        }
        Copy-Item $RealmSource "$($Img.Path)/keycloak/realm-export.json" -Force
        # Ensure certs directory exists in the build context
        if (-Not (Test-Path "$($Img.Path)/certs")) { New-Item -ItemType Directory -Path "$($Img.Path)/certs" }
        # Copy certificates if they exist locally
        $LocalCerts = Join-Path $RootPath "certs"
        if (Test-Path $LocalCerts) {
            Copy-Item (Join-Path $LocalCerts "*") "$($Img.Path)/certs/" -Force
        }
    } elseif ($Img.Name -eq "immich-server-custom") {
        if (-Not (Test-Path "$($Img.Path)/immich")) { New-Item -ItemType Directory -Path "$($Img.Path)/immich" }
        $ConfigSource = Join-Path $RootPath "immich/immich-config.$Environment.json"
        if (-Not (Test-Path $ConfigSource)) {
            Write-Error "Config file not found: $ConfigSource"
            exit 1
        }
        Copy-Item $ConfigSource "$($Img.Path)/immich/immich-config.json" -Force
    }

    docker build -t $FullTag (Join-Path $RootPath $Img.Path)
    
    if ($Push) {
        Write-Host "Pushing $FullTag..." -ForegroundColor Cyan
        docker push $FullTag
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to push $FullTag. Ensure you are logged in (docker login) and have permission."
            
            # Diagnostic help
            if ($Registry -notlike "*.*" -and $Registry -notlike "*/*") {
                Write-Host "ERROR: Registry '$Registry' seems to be missing a hostname." -ForegroundColor Red
                Write-Host "TIP: If you are using Docker Hub, use 'docker.io/$Registry' as your registry." -ForegroundColor Yellow
            }
            
            if ($Registry -like "ghcr.io*") {
                Write-Host "TIP: For GitHub Container Registry (ghcr.io), ensure your Personal Access Token (PAT) has the 'write:packages' scope." -ForegroundColor Yellow
                Write-Host "     If the repository is private, you may also need to grant the PAT permission to that specific repository." -ForegroundColor Yellow
            } elseif ($Registry -like "*azurecr.io*") {
                Write-Host "TIP: For Azure Container Registry, ensure you have the 'AcrPush' role or equivalent permissions." -ForegroundColor Yellow
            }
            exit 1
        }
    }
}

Write-Host "All images processed!" -ForegroundColor Green
