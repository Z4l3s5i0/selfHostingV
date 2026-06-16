# Keycloak Member Onboarding Script for Immich
$KC_CONTAINER = "keycloak"
$REALM = "selfHosting"
$CLIENT_NAME = "immich"

Write-Host "`n=== Immich Member Onboarding ===" -ForegroundColor Cyan

# Helper Functions (Reused from bootstrap script)
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

# 1. Collect Member Information
Write-Host "`nPlease enter the details for the new community member:" -ForegroundColor White
$M_USERNAME = Read-Host "Username"
$M_EMAIL = Read-Host "Email Address"
$M_FIRSTNAME = Read-Host "First Name"
$M_LASTNAME = Read-Host "Last Name"

if ([string]::IsNullOrWhiteSpace($M_USERNAME) -or [string]::IsNullOrWhiteSpace($M_EMAIL)) {
    Write-Host "`nError: Username and Email are required." -ForegroundColor Red
    exit 1
}

$DEFAULT_PASSWORD = "Community2026!"
Write-Host "`nPassword Policy:" -ForegroundColor Yellow
Write-Host " - Minimum 8 characters"
Write-Host " - Minimum 1 digit"
Write-Host " - Minimum 1 special character"
Write-Host " - Minimum 1 capital letter"
Write-Host " - Cannot contain Username or Email address"

$M_PASSWORD = ""
while ($true) {
    Write-Host "`nOptions:" -ForegroundColor Cyan
    Write-Host " [1] Use standard password ($DEFAULT_PASSWORD)"
    Write-Host " [2] Set custom password"
    $p_choice = Read-Host "Choice"

    if ($p_choice -eq "1") {
        $M_PASSWORD = $DEFAULT_PASSWORD
        break
    } elseif ($p_choice -eq "2") {
        $custom_p = Read-Host "Enter Custom Password"
        
        # Validation
        $isValid = $true
        if ($custom_p.Length -lt 8) { Write-Host " - Error: Password must be at least 8 characters." -ForegroundColor Red; $isValid = $false }
        if ($custom_p -notmatch '[0-9]') { Write-Host " - Error: Password must contain at least one digit." -ForegroundColor Red; $isValid = $false }
        if ($custom_p -notmatch '[^a-zA-Z0-9]') { Write-Host " - Error: Password must contain at least one special character." -ForegroundColor Red; $isValid = $false }
        if ($custom_p -notmatch '[A-Z]') { Write-Host " - Error: Password must contain at least one capital letter." -ForegroundColor Red; $isValid = $false }
        if ($custom_p.ToLower().Contains($M_USERNAME.ToLower())) { Write-Host " - Error: Password cannot contain the username." -ForegroundColor Red; $isValid = $false }
        if ($custom_p.ToLower().Contains($M_EMAIL.ToLower())) { Write-Host " - Error: Password cannot contain the email address." -ForegroundColor Red; $isValid = $false }

        if ($isValid) {
            $M_PASSWORD = $custom_p
            break
        }
    } else {
        Write-Host "Invalid choice. Please select 1 or 2." -ForegroundColor Red
    }
}

$IS_ADMIN = Read-Host "`nGrant Admin Rights? (y/N)"

$ROLE_TO_ASSIGN = "immich_user"
if ($IS_ADMIN -eq 'y' -or $IS_ADMIN -eq 'Y') {
    $ROLE_TO_ASSIGN = "immich_admin"
}

# 2. Authenticate
$auth = Execute-KC-Command "`nAuthenticating as admin" @("config", "credentials", "--server", "http://localhost:8080/auth", "--realm", "master", "--user", "admin", "--password", "admin")
if ($LASTEXITCODE -ne 0) { exit 1 }

# 3. Create User
Write-Host "Creating user '$M_USERNAME'..." -NoNewline
$output = & {
    $ErrorActionPreference = 'Continue'
    docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh create users -r $REALM -s username=$M_USERNAME -s email=$M_EMAIL -s firstName=$M_FIRSTNAME -s lastName=$M_LASTNAME -s enabled=true 2>&1
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

# 4. Fetch User ID
Write-Host "Fetching User ID..." -NoNewline
$USER_ID = $null
for ($i = 1; $i -le 3; $i++) {
    $raw = docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh get users -r $REALM -q username=$M_USERNAME --fields id
    $USER_ID = Get-ID-From-JSON $raw
    
    if (-not $USER_ID) {
        $raw = docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh get users -r $REALM -q email=$M_EMAIL --fields id
        $USER_ID = Get-ID-From-JSON $raw
    }

    if ($USER_ID) { break }
    Start-Sleep -Seconds 2
}

if (-not $USER_ID) {
    Write-Host " FAILED" -ForegroundColor Red
    exit 1
}
Write-Host " SUCCESS ($USER_ID)" -ForegroundColor Green

# 5. Set Password
Execute-KC-Command "Setting password" @("set-password", "-r", $REALM, "--userid", $USER_ID, "--new-password", $M_PASSWORD)

# 6. Fetch Client ID
Write-Host "Fetching Client ID for '$CLIENT_NAME'..." -NoNewline
$rawClient = docker exec $KC_CONTAINER /opt/keycloak/bin/kcadm.sh get clients -r $REALM -q clientId=$CLIENT_NAME --fields id
$CLIENT_ID_UUID = Get-ID-From-JSON $rawClient

if (-not $CLIENT_ID_UUID) {
    Write-Host " FAILED" -ForegroundColor Red
    exit 1
}
Write-Host " SUCCESS ($CLIENT_ID_UUID)" -ForegroundColor Green

# 7. Assign Role
Execute-KC-Command "Assigning '$ROLE_TO_ASSIGN' role" @("add-roles", "-r", $REALM, "--uid", $USER_ID, "--cclientid", $CLIENT_NAME, "--rolename", $ROLE_TO_ASSIGN)

Write-Host "`nDONE: Member '$M_USERNAME' has been onboarded successfully." -ForegroundColor Green
Write-Host "They can now log in at http://localhost:2283 with their credentials." -ForegroundColor White
