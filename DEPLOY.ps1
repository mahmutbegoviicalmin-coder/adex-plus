# ADEX PLUS — GitHub + Vercel Auto Deploy
# Pokreni: Right-click -> "Run with PowerShell"

$ErrorActionPreference = "Stop"
$GH_TOKEN      = $env:GH_TOKEN
$VERCEL_TOKEN  = $env:VERCEL_TOKEN
$RESEND_KEY    = $env:RESEND_KEY
$REPO_NAME     = "adex-plus"
$DIR           = Split-Path -Parent $MyInvocation.MyCommand.Path

Set-Location $DIR

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ADEX PLUS — GitHub + Vercel Deploy" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. npm install ──────────────────────────────────────────────
Write-Host "[1/5] npm install..." -ForegroundColor Yellow
npm install --silent
Write-Host "      OK" -ForegroundColor Green

# ── 2. Git init + commit ─────────────────────────────────────────
Write-Host "[2/5] Git init + commit..." -ForegroundColor Yellow
if (-not (Test-Path ".git")) { git init -q }
git config user.email "adnannarudzbe@gmail.com"
git config user.name "ADEX PLUS"
git add -A
git commit -q -m "Initial commit — ADEX PLUS landing page" 2>$null
Write-Host "      OK" -ForegroundColor Green

# ── 3. GitHub repo ───────────────────────────────────────────────
Write-Host "[3/5] Kreiram GitHub repo..." -ForegroundColor Yellow

$ghHeaders = @{
    "Authorization" = "token $GH_TOKEN"
    "Accept"        = "application/vnd.github.v3+json"
    "Content-Type"  = "application/json"
}
$ghBody = @{ name = $REPO_NAME; private = $false; description = "ADEX PLUS zastitna radna obuca" } | ConvertTo-Json

try {
    $ghResp = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method POST -Headers $ghHeaders -Body $ghBody
    $GH_USER = $ghResp.owner.login
    $REPO_URL = $ghResp.clone_url
    Write-Host "      Repo kreiran: $REPO_URL" -ForegroundColor Green
} catch {
    # Repo mozda vec postoji, pokusaj dobiti info
    $ghUser = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $ghHeaders
    $GH_USER = $ghUser.login
    $REPO_URL = "https://github.com/$GH_USER/$REPO_NAME.git"
    Write-Host "      Repo vec postoji, koristim: $REPO_URL" -ForegroundColor Yellow
}

$authUrl = "https://$GH_TOKEN@github.com/$GH_USER/$REPO_NAME.git"
git remote remove origin 2>$null
git remote add origin $authUrl
git branch -M main
git push -u origin main -q --force
Write-Host "      Pushano na GitHub" -ForegroundColor Green

# ── 4. Vercel deploy ─────────────────────────────────────────────
Write-Host "[4/5] Vercel deployment..." -ForegroundColor Yellow

$vHeaders = @{
    "Authorization" = "Bearer $VERCEL_TOKEN"
    "Content-Type"  = "application/json"
}

# Kreiraj Vercel projekt
$vProject = @{
    name      = $REPO_NAME
    framework = $null
    gitRepository = @{
        type = "github"
        repo = "$GH_USER/$REPO_NAME"
    }
} | ConvertTo-Json -Depth 5

try {
    $proj = Invoke-RestMethod -Uri "https://api.vercel.com/v10/projects" -Method POST -Headers $vHeaders -Body $vProject
    $PROJECT_ID = $proj.id
    Write-Host "      Vercel projekt kreiran: $($proj.name)" -ForegroundColor Green
} catch {
    # Projekt vec postoji
    $projs = Invoke-RestMethod -Uri "https://api.vercel.com/v9/projects?search=$REPO_NAME" -Headers $vHeaders
    $proj  = $projs.projects | Where-Object { $_.name -eq $REPO_NAME } | Select-Object -First 1
    $PROJECT_ID = $proj.id
    Write-Host "      Projekt vec postoji, ID: $PROJECT_ID" -ForegroundColor Yellow
}

# ── 5. Environment varijable ─────────────────────────────────────
Write-Host "[5/5] Dodajem env varijable na Vercel..." -ForegroundColor Yellow

$envBody = @(
    @{ key = "RESEND_API_KEY"; value = $RESEND_KEY; type = "encrypted"; target = @("production","preview","development") }
) | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "https://api.vercel.com/v10/projects/$PROJECT_ID/env" `
        -Method POST -Headers $vHeaders -Body $envBody | Out-Null
    Write-Host "      RESEND_API_KEY dodana" -ForegroundColor Green
} catch {
    Write-Host "      Env varijabla vec postoji ili greska: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Trigger deployment
$deployBody = @{
    name   = $REPO_NAME
    gitSource = @{
        type   = "github"
        repoId = $REPO_NAME
        ref    = "main"
    }
    projectId = $PROJECT_ID
} | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT ZAVRSEN!" -ForegroundColor Green
Write-Host ""
Write-Host "  GitHub: https://github.com/$GH_USER/$REPO_NAME" -ForegroundColor Cyan
Write-Host "  Vercel: https://$REPO_NAME.vercel.app" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Vercel ce automatski deployati sa GitHub!" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Pritisni Enter za izlaz..."
Read-Host
