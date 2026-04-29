# ADEX PLUS — Provjeri status deploymenta
# Pokreni: Right-click -> "Run with PowerShell"

$VERCEL_TOKEN = $env:VERCEL_TOKEN
$PROJECT_ID   = "prj_rr1pWsny3bDzfC9GH422C4tVhoq1"
$GH_TOKEN     = $env:GH_TOKEN
$REPO_NAME    = "adex-plus"

$headers = @{ "Authorization" = "Bearer $VERCEL_TOKEN" }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ADEX PLUS — Deployment Status Check" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Provjeri posljednje deploymente
Write-Host "[1] Dohvatam listu deploymenta..." -ForegroundColor Yellow
try {
    $resp = Invoke-RestMethod "https://api.vercel.com/v6/deployments?projectId=$PROJECT_ID&limit=5" -Headers $headers
    $deps = $resp.deployments

    if ($deps.Count -eq 0) {
        Write-Host "    Nema deploymenta jos." -ForegroundColor Red
    } else {
        Write-Host "    Pronadeno $($deps.Count) deploymenata:" -ForegroundColor Green
        Write-Host ""
        foreach ($d in $deps) {
            $state = $d.readyState
            $color = if ($state -eq "READY") { "Green" } elseif ($state -eq "ERROR") { "Red" } else { "Yellow" }
            Write-Host "    State : $state" -ForegroundColor $color
            Write-Host "    URL   : https://$($d.url)" -ForegroundColor Cyan
            Write-Host "    ID    : $($d.uid)" -ForegroundColor Gray
            Write-Host ""
        }

        # Uzmi najnoviji READY deployment
        $ready = $deps | Where-Object { $_.readyState -eq "READY" } | Select-Object -First 1
        if ($ready) {
            Write-Host "==========================================" -ForegroundColor Green
            Write-Host "  SAJT JE LIVE!" -ForegroundColor Green
            Write-Host "  URL: https://$($ready.url)" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "    Greska: $($_.Exception.Message)" -ForegroundColor Red
}

# Ako nema deploymenta, napravi novi
Write-Host ""
$choice = Read-Host "Zelis napraviti novi deployment? (y/n)"
if ($choice -eq "y") {
    Write-Host ""
    Write-Host "[2] Pushanje na GitHub..." -ForegroundColor Yellow

    $DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $DIR

    # Git push
    $ghUser = (Invoke-RestMethod "https://api.github.com/user" -Headers @{"Authorization"="token $GH_TOKEN"}).login
    $authUrl = "https://$GH_TOKEN@github.com/$ghUser/$REPO_NAME.git"

    git remote remove origin 2>$null
    git remote add origin $authUrl
    git add -A
    git commit -m "Update $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>$null
    git push -u origin main --force -q
    Write-Host "    Pushano na GitHub!" -ForegroundColor Green

    # Trigger Vercel redeploy
    Write-Host "[3] Triggeram Vercel redeploy..." -ForegroundColor Yellow

    $deployBody = @{
        name      = $REPO_NAME
        projectId = $PROJECT_ID
        target    = "production"
        gitSource = @{
            type = "github"
            ref  = "main"
            repoId = "$ghUser/$REPO_NAME"
        }
    } | ConvertTo-Json -Depth 5

    try {
        $dep = Invoke-RestMethod "https://api.vercel.com/v13/deployments" `
            -Method POST -Headers $headers -Body $deployBody -ContentType "application/json"
        Write-Host "    Deployment pokrenut!" -ForegroundColor Green
        Write-Host "    URL: https://$($dep.url)" -ForegroundColor Cyan
        Write-Host "    ID: $($dep.id)" -ForegroundColor Gray

        # Cekaj da bude READY
        Write-Host "[4] Cekam da deployment bude spreman..." -ForegroundColor Yellow
        $maxWait = 30
        $waited  = 0
        do {
            Start-Sleep -Seconds 5
            $waited += 5
            $status = Invoke-RestMethod "https://api.vercel.com/v13/deployments/$($dep.id)" -Headers $headers
            Write-Host "    Status: $($status.readyState) ($waited s)" -ForegroundColor Yellow
        } while ($status.readyState -notin @("READY","ERROR","CANCELED") -and $waited -lt ($maxWait * 5))

        if ($status.readyState -eq "READY") {
            Write-Host ""
            Write-Host "==========================================" -ForegroundColor Green
            Write-Host "  SAJT JE LIVE!" -ForegroundColor Green
            Write-Host "  URL: https://$($status.url)" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Green
        } else {
            Write-Host "    Final state: $($status.readyState)" -ForegroundColor Red
        }
    } catch {
        Write-Host "    Greska pri deployu: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Pritisni Enter za izlaz..."
Read-Host
