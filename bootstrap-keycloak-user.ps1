# Keycloak User Bootstrap Script for Immich (v11 - Regex JSON Extraction)
$KC_CONTAINER = "keycloak"
$REALM = "selfHosting"
$CLIENT_NAME = "immich"
$USERNAME = "admin_user"
$EMAIL = "admin@admin.ch"

Write-Host "`n--- Bootstrapping Keycloak User ---" -ForegroundColor Cyan

function Execute-KC-Command {
    param([string]$Message, [string[]]$Command)
    Write-Host "$Message..." -NoNewline
    
    $output = & {
        $ErrorActionPreference = 'Continue'
        docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh @Command 2>&1
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "Error Details: $output" -ForegroundColor Yellow
        return $null
    }
    Write-Host " SUCCESS" -ForegroundColor Green
    return $output
}

function Get-ID-From-JSON {
    param([string]$RawOutput)
    if ($RawOutput -match '(\[.*\])') {
        try {
            $jsonStr = $Matches[1]
            $obj = $jsonStr | ConvertFrom-Json
            if ($obj -is [array]) { return $obj[0].id }
            return $obj.id
        } catch { return $null }
    }
    return $null
}

# 1. Authenticate
$auth = Execute-KC-Command "Authenticating as admin" @("config", "credentials", "--server", "http://localhost:8080/auth", "--realm", "master", "--user", "admin", "--password", "admin")
if ($LASTEXITCODE -ne 0) { exit 1 }

# 2. Create User
Write-Host "Creating user '$USERNAME' ($EMAIL)..." -NoNewline
$output = & {
    $ErrorActionPreference = 'Continue'
    docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh create users -r $REALM -s username=$USERNAME -s email=$EMAIL -s firstName=admin -s lastName=admin -s enabled=true 2>&1
}
if ($LASTEXITCODE -ne 0) {
    if ($output -like "*already exists*" -or $output -like "*User exists with same email*") {
        Write-Host " ALREADY EXISTS (Continuing)" -ForegroundColor Yellow
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "Error Details: $output" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host " SUCCESS" -ForegroundColor Green
}

# 3. Fetch User ID
Write-Host "Fetching User ID..." -NoNewline
$USER_ID = $null
for ($i = 1; $i -le 3; $i++) {
    $raw = docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh get users -r $REALM -q username=$USERNAME --fields id
    $USER_ID = Get-ID-From-JSON $raw
    
    if (-not $USER_ID) {
        $raw = docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh get users -r $REALM -q email=$EMAIL --fields id
        $USER_ID = Get-ID-From-JSON $raw
    }

    if ($USER_ID) { break }
    Start-Sleep -Seconds 2
}

if (-not $USER_ID) {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "Debug: Raw output from Keycloak was: $raw" -ForegroundColor Gray
    exit 1
}
Write-Host " SUCCESS ($USER_ID)" -ForegroundColor Green

# 4. Set Password
# In Keycloak 26, set-password doesn't take -s. By default, it's non-temporary unless -t is passed.
Execute-KC-Command "Setting password" @("set-password", "-r", $REALM, "--userid", $USER_ID, "--new-password", "Test1234$")

# 5. Fetch Client ID
Write-Host "Fetching Client ID..." -NoNewline
$rawClient = docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh get clients -r $REALM -q clientId=$CLIENT_NAME --fields id
$CLIENT_ID_UUID = Get-ID-From-JSON $rawClient

if (-not $CLIENT_ID_UUID) {
    Write-Host " FAILED" -ForegroundColor Red
    exit 1
}
Write-Host " SUCCESS ($CLIENT_ID_UUID)" -ForegroundColor Green

# 6. Assign Client Role 'immich_admin'
Execute-KC-Command "Assigning 'immich_admin' role" @("add-roles", "-r", $REALM, "--uid", $USER_ID, "--cclientid", $CLIENT_NAME, "--rolename", "immich_admin")

Write-Host "`nDONE: User '$USERNAME' is fully configured for Immich." -ForegroundColor Green
Write-Host "Username: $USERNAME" -ForegroundColor White
Write-Host "Password: Test1234$" -ForegroundColor White
