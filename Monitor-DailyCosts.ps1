#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Daily cost monitoring script for sandbox resource group
    
.DESCRIPTION
    Checks current daily costs and sends alert if threshold exceeded.
    Designed to run via Windows Task Scheduler daily.
    
    Creates alert file and logs when costs are high.
    
.PARAMETER DailyThreshold
    Daily cost threshold in CAD (default: 10)
    
.PARAMETER EmailAlert
    Send email alert (requires Send-MailMessage configuration)
    
.EXAMPLE
    .\Monitor-DailyCosts.ps1
    Check current costs against $10 threshold
    
.EXAMPLE
    .\Monitor-DailyCosts.ps1 -DailyThreshold 15
    Check against $15 threshold
#>

param(
    [int]$DailyThreshold = 10,
    [switch]$EmailAlert
)

$ErrorActionPreference = "Continue"
Set-StrictMode -Version Latest

# Configuration
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$resourceGroup = "EsDAICoE-Sandbox"
$logFile = ".\cost-monitoring.log"
$alertFile = ".\COST-ALERT-$(Get-Date -Format 'yyyyMMdd').txt"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "ALERT" { Write-Host $logEntry -ForegroundColor Magenta }
        default { Write-Host $logEntry -ForegroundColor Gray }
    }
}

Write-Log "Starting daily cost monitoring..." "INFO"

# Set subscription
az account set --subscription $subscriptionId -o none

# Get current month costs for resource group
$startDate = (Get-Date -Day 1).ToString("yyyy-MM-dd")
$endDate = (Get-Date).ToString("yyyy-MM-dd")

Write-Log "Checking costs from $startDate to $endDate" "INFO"

try {
    # Get cost data
    $costs = az consumption usage list `
        --start-date $startDate `
        --end-date $endDate `
        --query "[?contains(instanceId, '$resourceGroup')].{Date:usageStart, Cost:pretaxCost, Resource:instanceName}" `
        -o json | ConvertFrom-Json
    
    if (-not $costs) {
        Write-Log "No cost data available yet" "WARN"
        exit 0
    }
    
    # Calculate today's costs
    $today = Get-Date -Format "yyyy-MM-dd"
    $todayCosts = $costs | Where-Object { $_.Date -like "$today*" } | Measure-Object -Property Cost -Sum
    $todayTotal = [math]::Round($todayCosts.Sum, 2)
    
    # Calculate month-to-date
    $monthTotal = [math]::Round(($costs | Measure-Object -Property Cost -Sum).Sum, 2)
    $daysInMonth = (Get-Date).Day
    $dailyAverage = [math]::Round($monthTotal / $daysInMonth, 2)
    $projectedMonth = [math]::Round($dailyAverage * (Get-Date).AddMonths(1).AddDays(-1).Day, 2)
    
    Write-Log "Today's costs: CAD `$$todayTotal" "INFO"
    Write-Log "Month-to-date: CAD `$$monthTotal" "INFO"
    Write-Log "Daily average: CAD `$$dailyAverage" "INFO"
    Write-Log "Projected month: CAD `$$projectedMonth" "INFO"
    
    # Check thresholds
    $alert = $false
    $alertMessage = ""
    
    if ($todayTotal -gt $DailyThreshold) {
        $alert = $true
        $alertMessage += "TODAY'S COSTS EXCEED THRESHOLD!`n"
        $alertMessage += "  Today: CAD `$$todayTotal (threshold: CAD `$$DailyThreshold)`n"
        $alertMessage += "  Overage: CAD `$$([math]::Round($todayTotal - $DailyThreshold, 2))`n`n"
        Write-Log "ALERT: Today's costs (CAD `$$todayTotal) exceed threshold (CAD `$$DailyThreshold)" "ALERT"
    }
    
    if ($projectedMonth -gt 220) {
        $alert = $true
        $alertMessage += "MONTHLY PROJECTION EXCEEDS BUDGET!`n"
        $alertMessage += "  Projected: CAD `$$projectedMonth (budget: CAD `$220)`n"
        $alertMessage += "  Overage: CAD `$$([math]::Round($projectedMonth - 220, 2))`n`n"
        Write-Log "ALERT: Projected month (CAD `$$projectedMonth) exceeds budget (CAD `$220)" "ALERT"
    }
    
    # Get top 5 expensive resources
    $topResources = $costs | Group-Object Resource | ForEach-Object {
        [PSCustomObject]@{
            Resource = $_.Name
            TotalCost = [math]::Round(($_.Group | Measure-Object -Property Cost -Sum).Sum, 2)
        }
    } | Sort-Object TotalCost -Descending | Select-Object -First 5
    
    # Create alert file if threshold exceeded
    if ($alert) {
        $alertContent = @"
========================================
  SANDBOX COST ALERT
========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

$alertMessage

TOP 5 EXPENSIVE RESOURCES (Month-to-Date):

$($topResources | Format-Table -AutoSize | Out-String)

ACTIONS YOU CAN TAKE:

1. STOP COMPUTE NOW (saves `$29/month potential):
   .\Stop-Sandbox.ps1 -Force

2. CHECK WHAT'S RUNNING:
   az resource list --resource-group "$resourceGroup" --query "[].{Name:name, Type:type, State:properties.state}" -o table

3. REVIEW COSTS IN PORTAL:
   https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/costanalysis

4. CHECK DEPLOYMENT STATUS:
   - Is APIM still deploying? (costs start immediately)
   - Are FinOps resources deployed? (adds `$25/month)

========================================
"@
        
        Set-Content -Path $alertFile -Value $alertContent
        Write-Log "Alert file created: $alertFile" "ALERT"
        
        # Display alert
        Write-Host "`n" -NoNewline
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  COST ALERT!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host $alertContent -ForegroundColor Yellow
    } else {
        Write-Log "All costs within thresholds" "INFO"
        Write-Host "`n[PASS] Costs are within normal range" -ForegroundColor Green
        Write-Host "  Today: CAD `$$todayTotal (threshold: CAD `$$DailyThreshold)" -ForegroundColor White
        Write-Host "  Projected month: CAD `$$projectedMonth (budget: CAD `$220)" -ForegroundColor White
    }
    
    # Always show top 5 resources
    Write-Host "`nTop 5 Resources (Month-to-Date):" -ForegroundColor Cyan
    $topResources | Format-Table -AutoSize
    
} catch {
    Write-Log "Error checking costs: $_" "ERROR"
    exit 1
}

Write-Log "Cost monitoring completed" "INFO"
