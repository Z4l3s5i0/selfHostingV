# Deployment helper script for Phala Cloud

# Define the CVM ID (from phala cvms ls)
$CVM_ID = "4060dc2b-2ff9-44de-99b3-e1c33e750d80"

# Load environment variables from .env if it exists
if (Test-Path .env) {
    Write-Host "Loading environment variables from .env..." -ForegroundColor Gray
    Get-Content .env | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
        $name, $value = $_.Split('=', 2)
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $name = $name.Trim()
            $value = $value.Trim()
            # Remove optional quotes
            if ($value -match '^".*"$' -or $value -match "^'.*'$") {
                $value = $value.Substring(1, $value.Length - 2)
            }
            if (-not (Test-Path "env:$name")) {
                New-Item -Path "env:$name" -Value $value -Force | Out-Null
            }
        }
    }
}

# Define your Docker Registry (required for custom images)
$DOCKER_REGISTRY = $env:DOCKER_REGISTRY

if ([string]::IsNullOrWhiteSpace($DOCKER_REGISTRY)) {
    Write-Error "DOCKER_REGISTRY environment variable not set. Please set it to your registry (e.g., ghcr.io/youruser)."
    exit 1
}

# Validate Registry format
if ($DOCKER_REGISTRY -notlike "*.*" -and $DOCKER_REGISTRY -notlike "*/*") {
    Write-Warning "DOCKER_REGISTRY '$DOCKER_REGISTRY' seems to be missing a hostname (e.g., ghcr.io or docker.io)."
    Write-Host "If you are using Docker Hub, please use 'docker.io/$DOCKER_REGISTRY'." -ForegroundColor Yellow
}

# Pre-flight check: Docker Login
Write-Host "Checking Docker authentication for $DOCKER_REGISTRY..." -ForegroundColor Cyan
$RegistryDomain = $DOCKER_REGISTRY.Split('/')[0]
$DockerConfigPath = Join-Path $HOME ".docker\config.json"

if (Test-Path $DockerConfigPath) {
    $DockerConfig = Get-Content $DockerConfigPath | ConvertFrom-Json
    $Authed = $false
    if ($DockerConfig.auths) {
        foreach ($key in $DockerConfig.auths.PSObject.Properties.Name) {
            if ($key -like "*$RegistryDomain*") {
                $Authed = $true
                break
            }
        }
    }
    
    # Also check credential helpers
    if (-not $Authed -and $DockerConfig.credHelpers) {
        foreach ($key in $DockerConfig.credHelpers.PSObject.Properties.Name) {
            if ($key -like "*$RegistryDomain*") {
                $Authed = $true
                break
            }
        }
    }

    if (-not $Authed) {
        Write-Warning "No active login found for $RegistryDomain in $DockerConfigPath."
        Write-Host "Please run 'docker login $RegistryDomain' and try again." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Warning "Docker config file not found at $DockerConfigPath. Cannot verify login status."
    Write-Host "Ensure you have run 'docker login' for your registry." -ForegroundColor Yellow
}

Write-Host "Building and Pushing custom images to $DOCKER_REGISTRY..." -ForegroundColor Cyan
.\build-images.ps1 -Registry $DOCKER_REGISTRY

Write-Host "Starting deployment to Phala Cloud CVM: $CVM_ID..." -ForegroundColor Cyan

# Check if .env exists
if (-Not (Test-Path .env)) {
    Write-Error ".env file not found. Please create one based on the documentation."
    exit 1
}

# Run the phala deploy command
# --compose: specifies the Phala-optimized compose file
# --cvm-id: specifies the target CVM
# --env: includes environment variables from .env
# --pre-launch-script: includes the pre-launch script for initialization
# --wait: waits for the deployment to finish
#
phala deploy `
    --compose immich-compose.phala.yml `
    --cvm-id $CVM_ID `
    -e .env `
    --pre-launch-script prelaunch-script.phala.sh `
    --wait
# phala deploy `
#     --compose immich-compose.phala.yml `
#     -e .env `
#     --pre-launch-script prelaunch-script.phala.sh `
#     --wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment initiated successfully!" -ForegroundColor Green
} else {
    Write-Host "Deployment failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
