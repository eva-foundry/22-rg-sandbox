#!/usr/bin/env pwsh
<#
.SYNOPSIS
    START ALL - Start all sandbox compute resources
    
.DESCRIPTION
    Starts all App Service Plans and their associated web apps/functions.
    Typical startup time: 2-3 minutes.
    
    Starts:
    - App Service Plans (3x): Backend, Enrichment, Functions
    - Web Apps (2x): Backend API, Enrichment Service
    - Function App (1x): Document pipeline
    
.PARAMETER WhatIf
    Shows what would be started without actually starting
    
.PARAMETER HealthCheck
    Wait for health check after starting (adds 3-5 minutes)
    
.EXAMPLE
    .\Start-Sandbox.ps1
    Start all resources
    
.EXAMPLE
    .\Start-Sandbox.ps1 -HealthCheck
    Start and wait for services to be healthy
    
.EXAMPLE
    .\Start-Sandbox.ps1 -WhatIf
    Preview what would be started
#>

param(
    [switch]$WhatIf,
    [switch]$HealthCheck
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Configuration
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"  # EsDAICoESub
$resourceGroup = "EsDAICoE-Sandbox"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  SANDBOX START ALL" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host ""

# Set subscription context
Write-Host "[INFO] Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $subscriptionId -o none

# Resources to start
$webApps = @(
    "marco-sandbox-backend",
    "marco-sandbox-enrichment"
)

$functionApps = @(
    "marco-sandbox-func"
)

$allApps = $webApps + $functionApps

Write-Host "=== RESOURCES TO START ===" -ForegroundColor Yellow
Write-Host ""

foreach ($appName in $allApps) {
    try {
        $state = az webapp show --name $appName --resource-group $resourceGroup --query "state" -o tsv 2>$null
        
        if (-not $state) {
            $state = az functionapp show --name $appName --resource-group $resourceGroup --query "state" -o tsv 2>$null
        }
        
        $statusColor = if ($state -eq "Running") { "Green" } elseif ($state -eq "Stopped") { "Red" } else { "Yellow" }
        Write-Host "  $appName" -ForegroundColor White
        Write-Host "    Current State: $state" -ForegroundColor $statusColor
    } catch {
        Write-Host "  $appName" -ForegroundColor White
        Write-Host "    Current State: Unknown" -ForegroundColor Gray
    }
}

Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF] Would start $($allApps.Count) apps" -ForegroundColor Cyan
    Write-Host "[WHATIF] Estimated startup time: 2-3 minutes" -ForegroundColor Gray
    exit 0
}

# Start all apps
Write-Host "[ACTION] Starting all apps..." -ForegroundColor Cyan
$startTime = Get-Date

$startResults = @()

# Start web apps
foreach ($appName in $webApps) {
    Write-Host "`n  Starting: $appName..." -ForegroundColor White
    
    try {
        az webapp start --name $appName --resource-group $resourceGroup -o none
        Write-Host "  [PASS] $appName started" -ForegroundColor Green
        
        $startResults += [PSCustomObject]@{
            Resource = $appName
            Type = "Web App"
            Status = "Started"
            Timestamp = Get-Date -Format "HH:mm:ss"
        }
    } catch {
        Write-Host "  [FAIL] Failed to start $appName`: $_" -ForegroundColor Red
        $startResults += [PSCustomObject]@{
            Resource = $appName
            Type = "Web App"
            Status = "Failed"
            Timestamp = Get-Date -Format "HH:mm:ss"
        }
    }
}

# Start function apps
foreach ($appName in $functionApps) {
    Write-Host "`n  Starting: $appName..." -ForegroundColor White
    
    try {
        az functionapp start --name $appName --resource-group $resourceGroup -o none
        Write-Host "  [PASS] $appName started" -ForegroundColor Green
        
        $startResults += [PSCustomObject]@{
            Resource = $appName
            Type = "Function App"
            Status = "Started"
            Timestamp = Get-Date -Format "HH:mm:ss"
        }
    } catch {
        Write-Host "  [FAIL] Failed to start $appName`: $_" -ForegroundColor Red
        $startResults += [PSCustomObject]@{
            Resource = $appName
            Type = "Function App"
            Status = "Failed"
            Timestamp = Get-Date -Format "HH:mm:ss"
        }
    }
}

$elapsedSeconds = [math]::Round((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds, 1)

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  START COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$startResults | Format-Table -AutoSize

Write-Host "Startup Time: $elapsedSeconds seconds" -ForegroundColor Cyan
Write-Host ""

# Health checks
if ($HealthCheck) {
    Write-Host "[INFO] Running health checks (this takes 3-5 minutes)..." -ForegroundColor Cyan
    Write-Host "  Waiting for apps to warm up..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    $healthResults = @()
    
    # Check backend health
    Write-Host "`n  Checking backend health..." -ForegroundColor White
    try {
        $backendUrl = "https://marco-sandbox-backend.azurewebsites.net/health"
        $response = Invoke-RestMethod -Uri $backendUrl -TimeoutSec 10
        Write-Host "  [PASS] Backend is healthy" -ForegroundColor Green
        $healthResults += "Backend: Healthy"
    } catch {
        Write-Host "  [WARN] Backend not responding yet: $($_.Exception.Message)" -ForegroundColor Yellow
        $healthResults += "Backend: Not Ready"
    }
    
    # Check enrichment health
    Write-Host "`n  Checking enrichment service..." -ForegroundColor White
    try {
        $enrichmentUrl = "https://marco-sandbox-enrichment.azurewebsites.net/health"
        $response = Invoke-RestMethod -Uri $enrichmentUrl -TimeoutSec 10
        Write-Host "  [PASS] Enrichment service is healthy" -ForegroundColor Green
        $healthResults += "Enrichment: Healthy"
    } catch {
        Write-Host "  [WARN] Enrichment not responding yet: $($_.Exception.Message)" -ForegroundColor Yellow
        $healthResults += "Enrichment: Not Ready"
    }
    
    Write-Host "`nHealth Check Results:" -ForegroundColor Cyan
    $healthResults | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    Write-Host ""
    
    if ($healthResults -match "Not Ready") {
        Write-Host "[INFO] Some services need more time to warm up" -ForegroundColor Yellow
        Write-Host "  Wait another 2-3 minutes and try accessing the apps" -ForegroundColor White
    }
}

Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Wait 2-3 minutes for full warmup" -ForegroundColor White
Write-Host "  2. Backend: https://marco-sandbox-backend.azurewebsites.net/health" -ForegroundColor White
Write-Host "  3. Enrichment: https://marco-sandbox-enrichment.azurewebsites.net/health" -ForegroundColor White
Write-Host ""

Write-Host "TO STOP:" -ForegroundColor Cyan
Write-Host "  .\Stop-Sandbox.ps1" -ForegroundColor White
Write-Host ""

# Save start event to log
$logEntry = @{
    timestamp = Get-Date -Format "o"
    action = "start"
    resources = $startResults
    elapsed_seconds = $elapsedSeconds
    user = $env:USERNAME
} | ConvertTo-Json

$logFile = ".\sandbox-operations.log"
Add-Content -Path $logFile -Value $logEntry
Write-Host "[INFO] Operation logged to: $logFile" -ForegroundColor Gray
