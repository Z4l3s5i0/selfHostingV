# Immich Admin Bootstrap Script
$IMMICH_CONTAINER = "immich_server"
$DB_CONTAINER = "immich_postgres"
$ADMIN_EMAIL = "admin@admin.ch"
$ADMIN_NAME = "Admin"
$ADMIN_PASSWORD = "Test1234$"

Write-Host "`n--- Bootstrapping Immich Admin ---" -ForegroundColor Cyan

# 1. Wait for Postgres to be ready
Write-Host "Waiting for database to be ready..." -NoNewline
$retries = 10
while ($retries -gt 0) {
    $check = docker exec $DB_CONTAINER pg_isready -U postgres -d immich 2>&1
    if ($check -like "*accepting connections*") {
        Write-Host " READY" -ForegroundColor Green
        break
    }
    $retries--
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 3
}

if ($retries -eq 0) {
    Write-Host " FAILED (Database timeout)" -ForegroundColor Red
    exit 1
}

# 2. Check if any user exists
$userCount = docker exec $DB_CONTAINER psql -U postgres -d immich -t -c "SELECT count(*) FROM public.user;"
$userCount = $userCount.Trim()

if ($userCount -ne "0") {
    Write-Host "Users already exist in Immich ($userCount)." -ForegroundColor Yellow
    
    # Still ensure onboarding is set even if user exists
    Write-Host "Ensuring onboarding status is set..." -NoNewline
    $onboardingSql = "INSERT INTO public.system_metadata (key, value) VALUES ('admin-onboarding', '{\`"isOnboarded\`": true}') ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;"
    $onboardingUpdate = docker exec $DB_CONTAINER psql -U postgres -d immich -c "$onboardingSql" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " SUCCESS" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
    
    exit 0
}

# 3. Generate Bcrypt hash for password
Write-Host "Generating password hash..." -NoNewline
$hash = docker exec -w /usr/src/app/server $IMMICH_CONTAINER node -e "const bcrypt = require('bcrypt'); console.log(bcrypt.hashSync('$ADMIN_PASSWORD', 10));" 2>&1
if ($LASTEXITCODE -ne 0 -or $hash -notlike '$2b$*') {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "Error: Could not generate bcrypt hash. Details: $hash" -ForegroundColor Yellow
    exit 1
}
Write-Host " SUCCESS" -ForegroundColor Green

# 4. Insert Admin User
Write-Host "Inserting admin user into database..." -NoNewline
$sql = "INSERT INTO public.user (email, password, name, \`"isAdmin\`", \`"shouldChangePassword\`", status) VALUES ('$ADMIN_EMAIL', '$hash', '$ADMIN_NAME', true, false, 'active');"
$insert = docker exec $DB_CONTAINER psql -U postgres -d immich -c "$sql" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "Error Details: $insert" -ForegroundColor Yellow
    exit 1
}
Write-Host " SUCCESS" -ForegroundColor Green

# 5. Set Onboarding Status
Write-Host "Setting onboarding status..." -NoNewline
$onboardingSql = "INSERT INTO public.system_metadata (key, value) VALUES ('admin-onboarding', '{\`"isOnboarded\`": true}') ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;"
$onboardingUpdate = docker exec $DB_CONTAINER psql -U postgres -d immich -c "$onboardingSql" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "Error Details: $onboardingUpdate" -ForegroundColor Yellow
    exit 1
}
Write-Host " SUCCESS" -ForegroundColor Green

Write-Host "`nDONE: Immich admin '$ADMIN_EMAIL' has been created and onboarding completed." -ForegroundColor Green
Write-Host "You can now log in at http://localhost:2283" -ForegroundColor White
