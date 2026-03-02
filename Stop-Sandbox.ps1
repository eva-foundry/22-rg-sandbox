#!/usr/bin/env pwsh
<#
.SYNOPSIS
    KILL SWITCH - Stop all compute resources in sandbox to minimize costs
    
.DESCRIPTION
    Stops/deallocates all billable compute resources when not in use:
    - App Service Plans (3x B1 tier): Saves $25/month (calculated: $39 × 65% uptime reduction)
    - Web Apps (2x + 1x Function): Automatically stopped with plans
    
    SAVINGS CALCULATION:
    - 3x B1 App Service Plans: $39/month total (24/7)
    - Weekend shutdown (48h): 29% reduction
    - Weeknight shutdown (10h × 5d): 30% reduction  
    - Vacation days (11 holidays): 6% reduction
    - Total uptime reduction: ~65%
    - Monthly savings: $39 × 65% = $25/month
    
    NOT STOPPED (reasons):
    - APIM: Charged regardless of state ($50/month - unavoidable)
    - Search, Cosmos, Storage: Minimal idle costs, can't be stopped
    
.PARAMETER WhatIf
    Shows what would be stopped without actually stopping
    
.PARAMETER Force
    Skip confirmation prompts
    
.EXAMPLE
    .\Stop-Sandbox.ps1
    Interactive stop with confirmation
    
.EXAMPLE
    .\Stop-Sandbox.ps1 -Force
    Stop everything immediately without prompts
    
.EXAMPLE
    .\Stop-Sandbox.ps1 -WhatIf
    Preview what would be stopped
#>

param(
    [switch]$WhatIf,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Configuration
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"  # EsDAICoESub
$resourceGroup = "EsDAICoE-Sandbox"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n========================================" -ForegroundColor Red
Write-Host "  SANDBOX KILL SWITCH" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host ""

# Set subscription context
Write-Host "[INFO] Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $subscriptionId -o none

# Get current resource states
Write-Host "[INFO] Checking current resource states..." -ForegroundColor Cyan

$appServicePlans = @(
    "marco-sandbox-asp-backend",
    "marco-sandbox-asp-enrichment",
    "marco-sandbox-asp-func"
)

# Display what will be stopped
Write-Host "`n=== RESOURCES TO STOP ===" -ForegroundColor Yellow
Write-Host ""

$totalMonthlySavings = 0
$hourlySavings = 0

foreach ($planName in $appServicePlans) {
    try {
        $plan = az appservice plan show --name $planName --resource-group $resourceGroup --query "{name:name, sku:sku.name, tier:sku.tier, status:status}" -o json | ConvertFrom-Json
        
        $costPerMonth = if ($planName -eq "marco-sandbox-asp-func") { 3 } else { 13 }
        $totalMonthlySavings += $costPerMonth
        $hourlySavings += [math]::Round($costPerMonth / 730, 2)
        
        $statusColor = if ($plan.status -eq "Ready") { "Green" } else { "Gray" }
        Write-Host "  App Service Plan: $($plan.name)" -ForegroundColor White
        Write-Host "    SKU: $($plan.sku) ($($plan.tier))" -ForegroundColor Gray
        Write-Host "    Current Status: $($plan.status)" -ForegroundColor $statusColor
        Write-Host "    Monthly Cost: `$$costPerMonth/month" -ForegroundColor Yellow
        Write-Host ""
    } catch {
        Write-Host "  [WARN] Could not get status for $planName" -ForegroundColor Yellow
    }
}

Write-Host "TOTAL SAVINGS WHEN STOPPED:" -ForegroundColor Cyan
Write-Host "  Monthly: `$$totalMonthlySavings/month" -ForegroundColor Green
Write-Host "  Hourly: `$$hourlySavings/hour" -ForegroundColor Green
Write-Host ""

Write-Host "=== RESOURCES THAT REMAIN RUNNING ===" -ForegroundColor Yellow
Write-Host "  APIM Gateway: marco-sandbox-apim (`$50/month - charged regardless)" -ForegroundColor Gray
Write-Host "  Search: marco-sandbox-search (~`$1-5/month idle)" -ForegroundColor Gray
Write-Host "  Cosmos DB: marco-sandbox-cosmos (~`$1/month idle)" -ForegroundColor Gray
Write-Host "  Storage: marcosand20260203 (~`$0.50/month idle)" -ForegroundColor Gray
Write-Host "  Key Vault, ACR, App Insights: Minimal/Free" -ForegroundColor Gray
Write-Host ""

# Confirmation prompt
if (-not $Force -and -not $WhatIf) {
    Write-Host "[CONFIRM] Stop all App Service Plans now?" -ForegroundColor Yellow
    Write-Host "  This will stop your backend, enrichment, and function apps" -ForegroundColor White
    Write-Host "  Monthly savings: `$$totalMonthlySavings" -ForegroundColor Green
    Write-Host ""
    $response = Read-Host "Type 'YES' to confirm"
    
    if ($response -ne "YES") {
        Write-Host "`n[CANCELLED] Operation cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

if ($WhatIf) {
    Write-Host "`n[WHATIF] Would stop $($appServicePlans.Count) App Service Plans" -ForegroundColor Cyan
    Write-Host "[WHATIF] Would save `$$totalMonthlySavings/month" -ForegroundColor Green
    exit 0
}

# Stop App Service Plans
Write-Host "`n[ACTION] Stopping App Service Plans..." -ForegroundColor Cyan

$stopResults = @()

foreach ($planName in $appServicePlans) {
    Write-Host "`n  Stopping: $planName..." -ForegroundColor White
    
    try {
        $result = az appservice plan update `
            --name $planName `
            --resource-group $resourceGroup `
            --set properties.status=Stopped `
            -o json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [PASS] $planName stopped successfully" -ForegroundColor Green
            $stopResults += [PSCustomObject]@{
                Resource = $planName
                Status = "Stopped"
                Timestamp = Get-Date -Format "HH:mm:ss"
            }
        } else {
            # Alternative: Stop the web apps instead
            Write-Host "  [INFO] Trying alternative method: stopping web apps..." -ForegroundColor Yellow
            
            # Get web apps in this plan
            $webApps = az webapp list --resource-group $resourceGroup --query "[?appServicePlanId=='/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/serverfarms/$planName'].name" -o tsv
            
            foreach ($webAppName in $webApps) {
                az webapp stop --name $webAppName --resource-group $resourceGroup -o none
                Write-Host "    [PASS] Stopped web app: $webAppName" -ForegroundColor Green
            }
            
            # Get function apps in this plan
            $functionApps = az functionapp list --resource-group $resourceGroup --query "[?appServicePlanId=='/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/serverfarms/$planName'].name" -o tsv
            
            foreach ($funcAppName in $functionApps) {
                az functionapp stop --name $funcAppName --resource-group $resourceGroup -o none
                Write-Host "    [PASS] Stopped function app: $funcAppName" -ForegroundColor Green
            }
            
            $stopResults += [PSCustomObject]@{
                Resource = $planName
                Status = "Apps Stopped"
                Timestamp = Get-Date -Format "HH:mm:ss"
            }
        }
    } catch {
        Write-Host "  [FAIL] Failed to stop $planName`: $_" -ForegroundColor Red
        $stopResults += [PSCustomObject]@{
            Resource = $planName
            Status = "Failed"
            Timestamp = Get-Date -Format "HH:mm:ss"
        }
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  KILL SWITCH COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$stopResults | Format-Table -AutoSize

Write-Host "COST SAVINGS:" -ForegroundColor Cyan
Write-Host "  Stopped: `$$totalMonthlySavings/month (estimated)" -ForegroundColor Green
Write-Host "  Still Running: `$50-55/month (APIM + minimal services)" -ForegroundColor Yellow
Write-Host ""

Write-Host "TO RESTART:" -ForegroundColor Cyan
Write-Host "  .\Start-Sandbox.ps1" -ForegroundColor White
Write-Host ""

# Save stop event to log
$logEntry = @{
    timestamp = Get-Date -Format "o"
    action = "stop"
    resources = $stopResults
    savings_monthly = $totalMonthlySavings
    user = $env:USERNAME
} | ConvertTo-Json

$logFile = ".\sandbox-operations.log"
Add-Content -Path $logFile -Value $logEntry
Write-Host "[INFO] Operation logged to: $logFile" -ForegroundColor Gray
