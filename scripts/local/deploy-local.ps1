# Local deployment script for Immich stack

# Load environment variables from .env if it exists
$EnvFile = Join-Path $PSScriptRoot "../../.env"
if (Test-Path $EnvFile) {
    Write-Host "Loading environment variables from .env..." -ForegroundColor Gray
    Get-Content $EnvFile | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
        $name, $value = $_.Split('=', 2)
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $name = $name.Trim()
            $value = $value.Trim()
            # Remove optional quotes
            if ($value -match '^".*"$' -or $value -match "^'.*'$") {
                $value = $value.Substring(1, $value.Length - 2)
            }
            # Set environment variable for the current session
            [System.Environment]::SetEnvironmentVariable($name, $value, [System.EnvironmentVariableTarget]::Process)
        }
    }
}

# Define your Docker Registry
$DOCKER_REGISTRY = $env:DOCKER_REGISTRY
if ([string]::IsNullOrWhiteSpace($DOCKER_REGISTRY)) {
    Write-Host "DOCKER_REGISTRY environment variable not set. Defaulting to 'local-immich'." -ForegroundColor Yellow
    $DOCKER_REGISTRY = "local-immich"
    $env:DOCKER_REGISTRY = $DOCKER_REGISTRY
}

# 1. Run Pre-launch Logic
Write-Host "Running pre-launch logic (Cleanup & Certificates)..." -ForegroundColor Cyan

# Cleanup
Write-Host "Pruning unused images and volumes..." -ForegroundColor Gray
# docker image prune -af
# docker volume prune -f

# Force Keycloak re-import if requested
if ($env:FORCE_REIMPORT -eq "true") {
    Write-Host "FORCE_REIMPORT is true. Removing Keycloak MySQL volume to trigger fresh import..." -ForegroundColor Yellow
    docker compose -f (Join-Path $PSScriptRoot "../../immich-compose.local.yml") down -v mysql
}

# Certificates
$CertsDir = Join-Path $PSScriptRoot "../../certs"
if (-Not (Test-Path $CertsDir)) {
    New-Item -ItemType Directory -Path $CertsDir | Out-Null
}
$CertFile = Join-Path $CertsDir "server.crt"
$KeyFile = Join-Path $CertsDir "server.key"
if (-Not (Test-Path $CertFile)) {
    Write-Host "Generating self-signed certificates for localhost..." -ForegroundColor Gray
    openssl req -x509 -newkey rsa:4096 -nodes -sha256 -keyout $KeyFile -out $CertFile -subj "/CN=localhost" -days 365
} else {
    Write-Host "Certificates already exist, skipping generation." -ForegroundColor Gray
}

# 2. Build images
Write-Host "Building custom images..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "../build-images.ps1") -Registry $DOCKER_REGISTRY -Environment "local" -Push:$false

# 3. Pull external images
Write-Host "Pulling external images..." -ForegroundColor Cyan
$ComposeFile = Join-Path $PSScriptRoot "../../immich-compose.local.yml"
# List only external services to avoid overwriting locally built custom images
$ExternalServices = @("immich-machine-learning", "redis", "database", "node-exporter", "immich-exporter", "mysql")
docker compose -f $ComposeFile --env-file $EnvFile pull $ExternalServices

# 4. Launch Stack
Write-Host "Launching Immich stack locally..." -ForegroundColor Cyan
docker compose -f $ComposeFile --env-file $EnvFile up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nLocal deployment successful!" -ForegroundColor Green
    Write-Host "Immich is available at: http://localhost:2283" -ForegroundColor White
    Write-Host "Keycloak is available at: http://localhost:8080" -ForegroundColor White
} else {
    Write-Host "`nLocal deployment failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
