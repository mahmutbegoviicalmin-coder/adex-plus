# ============================================================
#  ADEX PLUS — Kompletni Vercel Deploy (Direct File Upload)
#  Pokreni: Desni klik -> "Run with PowerShell"
# ============================================================

$ErrorActionPreference = "Continue"

$VERCEL_TOKEN = $env:VERCEL_TOKEN
$RESEND_KEY   = $env:RESEND_KEY
$GH_TOKEN     = $env:GH_TOKEN
$REPO_NAME    = "adex-plus"
$DIR          = Split-Path -Parent $MyInvocation.MyCommand.Path

Set-Location $DIR

$vHeaders = @{ "Authorization" = "Bearer $VERCEL_TOKEN" }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ADEX PLUS — Vercel Full Deploy" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ── STEP 1: GitHub Push ─────────────────────────────────────
Write-Host "[1/6] Pushanje na GitHub..." -ForegroundColor Yellow
try {
    $ghUser = (Invoke-RestMethod "https://api.github.com/user" -Headers @{"Authorization"="token $GH_TOKEN"; "User-Agent"="ADEX"}).login
    Write-Host "      GitHub korisnik: $ghUser" -ForegroundColor Green

    if (-not (Test-Path ".git")) { git init -q }
    git config user.email "adnannarudzbe@gmail.com"
    git config user.name "ADEX PLUS"
    git remote remove origin 2>$null
    git remote add origin "https://$GH_TOKEN@github.com/$ghUser/$REPO_NAME.git"
    git add -A
    git commit -m "Deploy $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>$null
    git branch -M main
    git push -u origin main --force -q
    Write-Host "      Pushano na GitHub OK" -ForegroundColor Green
} catch {
    Write-Host "      GitHub push greska: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ── STEP 2: Provjeri/kreiraj Vercel projekt ─────────────────
Write-Host "[2/6] Vercel projekt..." -ForegroundColor Yellow
try {
    $projects = Invoke-RestMethod "https://api.vercel.com/v9/projects?search=$REPO_NAME" -Headers $vHeaders
    $proj = $projects.projects | Where-Object { $_.name -eq $REPO_NAME } | Select-Object -First 1
} catch { $proj = $null }

if (-not $proj) {
    Write-Host "      Kreiram novi projekt..." -ForegroundColor Yellow
    try {
        $proj = Invoke-RestMethod "https://api.vercel.com/v10/projects" -Method POST -Headers $vHeaders `
            -Body (@{ name = $REPO_NAME; framework = $null } | ConvertTo-Json) `
            -ContentType "application/json"
    } catch {
        Write-Host "      Greska pri kreiranju projekta: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Pritisni Enter za izlaz..."
        exit 1
    }
}
$PROJECT_ID = $proj.id
Write-Host "      Projekt ID: $PROJECT_ID" -ForegroundColor Green

# ── STEP 3: Environment varijable ───────────────────────────
Write-Host "[3/6] Postavljanje env varijabli..." -ForegroundColor Yellow

# Provjeri da li env varijabla vec postoji
try {
    $envList = Invoke-RestMethod "https://api.vercel.com/v9/projects/$PROJECT_ID/env" -Headers $vHeaders
    $existing = $envList.envs | Where-Object { $_.key -eq "RESEND_API_KEY" }

    if ($existing) {
        # Update existing
        $envBody = @{ value = $RESEND_KEY; type = "encrypted"; target = @("production","preview","development") } | ConvertTo-Json
        Invoke-RestMethod "https://api.vercel.com/v9/projects/$PROJECT_ID/env/$($existing.id)" `
            -Method PATCH -Headers $vHeaders -Body $envBody -ContentType "application/json" | Out-Null
        Write-Host "      RESEND_API_KEY azurirana" -ForegroundColor Green
    } else {
        # Create new
        $envBody = @(@{ key = "RESEND_API_KEY"; value = $RESEND_KEY; type = "encrypted"; target = @("production","preview","development") }) | ConvertTo-Json -Depth 5
        Invoke-RestMethod "https://api.vercel.com/v10/projects/$PROJECT_ID/env" `
            -Method POST -Headers $vHeaders -Body $envBody -ContentType "application/json" | Out-Null
        Write-Host "      RESEND_API_KEY dodana" -ForegroundColor Green
    }
} catch {
    Write-Host "      Env varijabla greska: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ── STEP 4: Upload fajlova ──────────────────────────────────
Write-Host "[4/6] Upload fajlova na Vercel..." -ForegroundColor Yellow

$sha1Engine = [System.Security.Cryptography.SHA1]::Create()

function Get-Sha1AndBytes($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hashBytes = $sha1Engine.ComputeHash($bytes)
    $hash = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
    return @{ hash = $hash; bytes = $bytes; size = $bytes.Length }
}

function Upload-ToVercel($fileInfo, $displayName) {
    $uhHeaders = @{
        "Authorization"   = "Bearer $VERCEL_TOKEN"
        "x-vercel-digest" = $fileInfo.hash
        "Content-Type"    = "application/octet-stream"
    }
    try {
        $resp = Invoke-WebRequest -Uri "https://api.vercel.com/v2/files" `
            -Method POST -Headers $uhHeaders -Body $fileInfo.bytes -UseBasicParsing
        if ($resp.StatusCode -in 200,201,409) {
            Write-Host "      OK: $displayName" -ForegroundColor Green
            return $true
        }
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($code -eq 409) {
            Write-Host "      VEC POSTOJI: $displayName" -ForegroundColor Gray
            return $true
        }
        Write-Host "      GRESKA ($code): $displayName — $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# Lista fajlova
$files = @(
    @{ local = "index.html";                remote = "index.html" }
    @{ local = "vercel.json";               remote = "vercel.json" }
    @{ local = "package.json";              remote = "package.json" }
    @{ local = "api\order.js";              remote = "api/order.js" }
    @{ local = "public\images\hero.png";    remote = "public/images/hero.png" }
    @{ local = "public\images\1.webp";      remote = "public/images/1.webp" }
    @{ local = "public\images\2.webp";      remote = "public/images/2.webp" }
    @{ local = "public\images\3.webp";      remote = "public/images/3.webp" }
    @{ local = "public\images\33.png";      remote = "public/images/33.png" }
)

$deployFiles = [System.Collections.ArrayList]::new()

foreach ($f in $files) {
    $fullPath = Join-Path $DIR $f.local
    if (-not (Test-Path $fullPath)) {
        Write-Host "      NEMA FAJLA: $($f.local)" -ForegroundColor Red
        continue
    }
    $info = Get-Sha1AndBytes $fullPath
    $ok   = Upload-ToVercel $info $f.remote
    if ($ok) {
        [void]$deployFiles.Add(@{
            file = $f.remote
            sha  = $info.hash
            size = $info.size
        })
    }
}

Write-Host "      Uploadovano $($deployFiles.Count)/$($files.Count) fajlova" -ForegroundColor Cyan

# ── STEP 5: Kreiraj deployment ──────────────────────────────
Write-Host "[5/6] Kreiram deployment na Vercel..." -ForegroundColor Yellow

$deployBody = @{
    name      = $REPO_NAME
    projectId = $PROJECT_ID
    target    = "production"
    files     = $deployFiles.ToArray()
    projectSettings = @{
        framework      = $null
        buildCommand   = $null
        outputDirectory = $null
        installCommand = "npm install"
        nodeVersion    = "18.x"
    }
} | ConvertTo-Json -Depth 10

try {
    $dep = Invoke-RestMethod "https://api.vercel.com/v13/deployments" `
        -Method POST -Headers $vHeaders -Body $deployBody -ContentType "application/json"
    $DEP_ID = $dep.id
    $DEP_URL = $dep.url
    Write-Host "      Deployment kreiran! ID: $DEP_ID" -ForegroundColor Green
    Write-Host "      URL: https://$DEP_URL" -ForegroundColor Cyan
} catch {
    Write-Host "      GRESKA pri kreiranju deploymenta:" -ForegroundColor Red
    Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    # Pokusaj dobiti response body
    try {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $body = $reader.ReadToEnd()
        Write-Host "      Response: $body" -ForegroundColor Yellow
    } catch {}
    Read-Host "Pritisni Enter za izlaz..."
    exit 1
}

# ── STEP 6: Cekaj READY ─────────────────────────────────────
Write-Host "[6/6] Cekam da sajt bude spreman..." -ForegroundColor Yellow

$maxTries = 30
$tries    = 0
$finalUrl = ""

do {
    Start-Sleep -Seconds 5
    $tries++
    try {
        $status = Invoke-RestMethod "https://api.vercel.com/v13/deployments/$DEP_ID" -Headers $vHeaders
        $state  = $status.readyState
        Write-Host "      [$tries] Status: $state" -ForegroundColor Yellow
        if ($state -eq "READY") {
            $finalUrl = "https://$($status.url)"
        }
    } catch {
        Write-Host "      Greska pri provjeri: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} while ($state -notin @("READY","ERROR","CANCELED") -and $tries -lt $maxTries)

Write-Host ""

if ($state -eq "READY") {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  SAJT JE LIVE!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  $finalUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  GitHub: https://github.com/$ghUser/$REPO_NAME" -ForegroundColor Gray
    Write-Host "  Vercel: https://vercel.com/$ghUser/$REPO_NAME" -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Za vlastitu domenu:" -ForegroundColor White
    Write-Host "  1. Idi na vercel.com -> projekat -> Settings -> Domains" -ForegroundColor White
    Write-Host "  2. Dodaj svoju domenu (npr. adexplus.ba)" -ForegroundColor White
    Write-Host "  3. Postavi DNS kod svog registrara prema Vercel uputama" -ForegroundColor White
    Write-Host ""
    # Kopiraj URL u clipboard
    $finalUrl | Set-Clipboard
    Write-Host "  URL je kopiran u clipboard!" -ForegroundColor Green
} elseif ($state -eq "ERROR") {
    Write-Host "  DEPLOYMENT GRESKA!" -ForegroundColor Red
    Write-Host "  Provjeri: https://vercel.com/$ghUser/$REPO_NAME" -ForegroundColor Yellow
} else {
    Write-Host "  Deployment jos uvijek u toku..." -ForegroundColor Yellow
    Write-Host "  Provjeri manuelno: https://vercel.com/$ghUser/$REPO_NAME" -ForegroundColor Cyan
    Write-Host "  URL bi trebao biti: https://$DEP_URL" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Pritisni Enter za izlaz..."
Read-Host
