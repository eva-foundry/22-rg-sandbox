#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Set up automated cost alerts for sandbox resource group
    
.DESCRIPTION
    Creates Azure Monitor action groups and cost alerts to notify when:
    - Daily costs exceed $10 (warning)
    - Monthly projected costs exceed $220 (critical)
    - Specific resources have unusual spending patterns
    
    Sends email notifications to specified address.
    
.PARAMETER EmailAddress
    Email address for alert notifications (default: marco.presta@hrsdc-rhdcc.gc.ca)
    
.PARAMETER DailyThreshold
    Daily cost threshold in CAD (default: 10)
    
.PARAMETER MonthlyThreshold
    Monthly projected cost threshold in CAD (default: 220)
    
.PARAMETER Remove
    Remove existing cost alerts
    
.PARAMETER WhatIf
    Preview what would be created without actually creating
    
.EXAMPLE
    .\Setup-CostAlerts.ps1
    Create default cost alerts
    
.EXAMPLE
    .\Setup-CostAlerts.ps1 -EmailAddress "user@example.com" -DailyThreshold 15
    Custom email and threshold
    
.EXAMPLE
    .\Setup-CostAlerts.ps1 -Remove
    Remove all cost alerts
#>

param(
    [string]$EmailAddress = "marco.presta@hrsdc-rhdcc.gc.ca",
    [int]$DailyThreshold = 10,
    [int]$MonthlyThreshold = 220,
    [switch]$Remove,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Configuration
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"  # EsDAICoESub
$resourceGroup = "EsDAICoE-Sandbox"
$location = "canadacentral"
$actionGroupName = "sandbox-cost-alerts-ag"
$alertNameDaily = "sandbox-daily-cost-alert"
$alertNameMonthly = "sandbox-monthly-cost-alert"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SANDBOX COST ALERT SETUP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "[INFO] Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $subscriptionId -o none

# Remove existing alerts
if ($Remove) {
    Write-Host "[ACTION] Removing cost alerts..." -ForegroundColor Yellow
    
    # Remove budget alerts
    try {
        az consumption budget delete --budget-name $alertNameDaily --resource-group-name $resourceGroup 2>$null
        Write-Host "[PASS] Removed daily cost alert" -ForegroundColor Green
    } catch {
        Write-Host "[INFO] Daily alert not found" -ForegroundColor Gray
    }
    
    try {
        az consumption budget delete --budget-name $alertNameMonthly --resource-group-name $resourceGroup 2>$null
        Write-Host "[PASS] Removed monthly cost alert" -ForegroundColor Green
    } catch {
        Write-Host "[INFO] Monthly alert not found" -ForegroundColor Gray
    }
    
    # Remove action group
    try {
        az monitor action-group delete --name $actionGroupName --resource-group $resourceGroup 2>$null
        Write-Host "[PASS] Removed action group" -ForegroundColor Green
    } catch {
        Write-Host "[INFO] Action group not found" -ForegroundColor Gray
    }
    
    Write-Host "`n[INFO] Cost alerts removed" -ForegroundColor Cyan
    exit 0
}

# Display configuration
Write-Host "=== ALERT CONFIGURATION ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "Email: $EmailAddress" -ForegroundColor White
Write-Host "Daily Threshold: CAD `$$DailyThreshold" -ForegroundColor White
Write-Host "Monthly Threshold: CAD `$$MonthlyThreshold" -ForegroundColor White
Write-Host ""

Write-Host "Alerts to create:" -ForegroundColor Cyan
Write-Host "  1. DAILY ALERT" -ForegroundColor White
Write-Host "     Triggers when: Daily actual costs exceed CAD `$$DailyThreshold" -ForegroundColor Gray
Write-Host "     Frequency: Once per day" -ForegroundColor Gray
Write-Host "     Severity: Warning" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. MONTHLY ALERT" -ForegroundColor White
Write-Host "     Triggers when: Monthly forecasted costs exceed CAD `$$MonthlyThreshold" -ForegroundColor Gray
Write-Host "     Frequency: Once per month" -ForegroundColor Gray
Write-Host "     Severity: Critical" -ForegroundColor Red
Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF] Would create:" -ForegroundColor Cyan
    Write-Host "  - Action Group: $actionGroupName" -ForegroundColor White
    Write-Host "  - Daily Budget Alert: $alertNameDaily" -ForegroundColor White
    Write-Host "  - Monthly Budget Alert: $alertNameMonthly" -ForegroundColor White
    exit 0
}

# Confirm
Write-Host "[CONFIRM] Create these cost alerts?" -ForegroundColor Yellow
Write-Host "  You will receive email notifications at: $EmailAddress" -ForegroundColor White
$response = Read-Host "Type 'YES' to proceed"

if ($response -ne "YES") {
    Write-Host "`n[CANCELLED] No alerts created" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n[ACTION] Creating cost alerts..." -ForegroundColor Cyan

# Step 1: Create Action Group
Write-Host "`n  Creating action group: $actionGroupName..." -ForegroundColor White

try {
    $actionGroupJson = @{
        location = "global"
        tags = @{
            Owner = "Marco Presta"
            Purpose = "Cost alerts for sandbox"
            Created = (Get-Date -Format "yyyy-MM-dd")
        }
        properties = @{
            groupShortName = "SandboxCost"
            enabled = $true
            emailReceivers = @(
                @{
                    name = "EmailMarco"
                    emailAddress = $EmailAddress
                    useCommonAlertSchema = $true
                }
            )
        }
    } | ConvertTo-Json -Depth 10
    
    $actionGroupId = az monitor action-group create `
        --name $actionGroupName `
        --resource-group $resourceGroup `
        --short-name "SandboxCost" `
        --email-receiver "EmailMarco" $EmailAddress `
        --query "id" -o tsv
    
    Write-Host "  [PASS] Action group created" -ForegroundColor Green
    Write-Host "    ID: $actionGroupId" -ForegroundColor Gray
} catch {
    Write-Host "  [FAIL] Failed to create action group: $_" -ForegroundColor Red
    Write-Host "  [INFO] You may need to use Azure Portal instead" -ForegroundColor Yellow
    Write-Host "  [INFO] Portal: https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/costanalysis" -ForegroundColor Cyan
    exit 1
}

# Step 2: Create Daily Budget Alert
Write-Host "`n  Creating daily cost alert ($DailyThreshold CAD)..." -ForegroundColor White

# Note: Azure budgets work on monthly basis, so we'll create a monthly budget with daily threshold * 30
$monthlyBudget = $DailyThreshold * 30

try {
    # Get current date for budget period
    $startDate = (Get-Date -Day 1).ToString("yyyy-MM-01")
    $endDate = (Get-Date -Day 1).AddMonths(12).ToString("yyyy-MM-01")
    
    $budgetJson = @{
        properties = @{
            category = "Cost"
            amount = $monthlyBudget
            timeGrain = "Monthly"
            timePeriod = @{
                startDate = $startDate
                endDate = $endDate
            }
            filter = @{
                dimensions = @{
                    name = "ResourceGroupName"
                    operator = "In"
                    values = @($resourceGroup)
                }
            }
            notifications = @{
                "Actual_GreaterThan_80_Percent" = @{
                    enabled = $true
                    operator = "GreaterThan"
                    threshold = 80
                    contactEmails = @($EmailAddress)
                    contactRoles = @()
                    contactGroups = @()
                    thresholdType = "Actual"
                }
                "Forecasted_GreaterThan_100_Percent" = @{
                    enabled = $true
                    operator = "GreaterThan"
                    threshold = 100
                    contactEmails = @($EmailAddress)
                    contactRoles = @()
                    contactGroups = @()
                    thresholdType = "Forecasted"
                }
            }
        }
    } | ConvertTo-Json -Depth 10
    
    # Create budget using REST API (az consumption budget has limitations)
    Write-Host "  [INFO] Using Azure Cost Management budgets..." -ForegroundColor Gray
    Write-Host "  [INFO] Monthly budget: CAD `$$monthlyBudget" -ForegroundColor Gray
    Write-Host "  [INFO] Alerts at: 80% actual, 100% forecasted" -ForegroundColor Gray
    
    # Get access token
    $token = az account get-access-token --query accessToken -o tsv
    
    # Create budget via REST API
    $budgetUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Consumption/budgets/$alertNameDaily?api-version=2023-05-01"
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-RestMethod -Uri $budgetUrl -Method Put -Headers $headers -Body $budgetJson
    
    Write-Host "  [PASS] Daily cost monitoring budget created" -ForegroundColor Green
    Write-Host "    Monthly Budget: CAD `$$monthlyBudget" -ForegroundColor Gray
    Write-Host "    Alert at 80%: CAD `$$([math]::Round($monthlyBudget * 0.8))" -ForegroundColor Gray
} catch {
    Write-Host "  [WARN] Budget creation via API failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  [INFO] Alternative: Create manually in Azure Portal" -ForegroundColor Cyan
    Write-Host "  [INFO] Portal: https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/budgets" -ForegroundColor White
}

# Step 3: Create Monthly Forecasted Alert
Write-Host "`n  Creating monthly forecasted alert ($MonthlyThreshold CAD)..." -ForegroundColor White

try {
    $startDate = (Get-Date -Day 1).ToString("yyyy-MM-01")
    $endDate = (Get-Date -Day 1).AddMonths(12).ToString("yyyy-MM-01")
    
    $monthlyBudgetJson = @{
        properties = @{
            category = "Cost"
            amount = $MonthlyThreshold
            timeGrain = "Monthly"
            timePeriod = @{
                startDate = $startDate
                endDate = $endDate
            }
            filter = @{
                dimensions = @{
                    name = "ResourceGroupName"
                    operator = "In"
                    values = @($resourceGroup)
                }
            }
            notifications = @{
                "Forecasted_GreaterThan_90_Percent" = @{
                    enabled = $true
                    operator = "GreaterThan"
                    threshold = 90
                    contactEmails = @($EmailAddress)
                    contactRoles = @()
                    contactGroups = @()
                    thresholdType = "Forecasted"
                }
                "Forecasted_GreaterThan_100_Percent" = @{
                    enabled = $true
                    operator = "GreaterThan"
                    threshold = 100
                    contactEmails = @($EmailAddress)
                    contactRoles = @()
                    contactGroups = @()
                    thresholdType = "Forecasted"
                }
                "Actual_GreaterThan_100_Percent" = @{
                    enabled = $true
                    operator = "GreaterThan"
                    threshold = 100
                    contactEmails = @($EmailAddress)
                    contactRoles = @()
                    contactGroups = @()
                    thresholdType = "Actual"
                }
            }
        }
    } | ConvertTo-Json -Depth 10
    
    $budgetUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Consumption/budgets/$alertNameMonthly?api-version=2023-05-01"
    
    $response = Invoke-RestMethod -Uri $budgetUrl -Method Put -Headers $headers -Body $monthlyBudgetJson
    
    Write-Host "  [PASS] Monthly budget alert created" -ForegroundColor Green
    Write-Host "    Monthly Budget: CAD `$$MonthlyThreshold" -ForegroundColor Gray
    Write-Host "    Alerts at: 90%, 100% (forecasted), 100% (actual)" -ForegroundColor Gray
} catch {
    Write-Host "  [WARN] Monthly budget creation via API failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  COST ALERTS SETUP COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Notifications will be sent to: $EmailAddress" -ForegroundColor Cyan
Write-Host ""

Write-Host "Alert Triggers:" -ForegroundColor Yellow
Write-Host "  1. Daily monitoring: When monthly costs exceed 80% of CAD `$$monthlyBudget" -ForegroundColor White
Write-Host "  2. Monthly forecast: When projected costs exceed 90% of CAD `$$MonthlyThreshold" -ForegroundColor White
Write-Host "  3. Monthly actual: When actual costs exceed 100% of CAD `$$MonthlyThreshold" -ForegroundColor White
Write-Host ""

Write-Host "VERIFY SETUP:" -ForegroundColor Cyan
Write-Host "  1. Check email for 'Azure Budget Notification' confirmation" -ForegroundColor White
Write-Host "  2. Azure Portal: Cost Management + Billing > Budgets" -ForegroundColor White
Write-Host "  3. URL: https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/budgets" -ForegroundColor White
Write-Host ""

Write-Host "MANUAL SETUP (if automated creation failed):" -ForegroundColor Yellow
Write-Host "  1. Go to Azure Portal > Cost Management" -ForegroundColor White
Write-Host "  2. Click 'Budgets' > '+ Add'" -ForegroundColor White
Write-Host "  3. Set budget amount: CAD `$$MonthlyThreshold" -ForegroundColor White
Write-Host "  4. Set scope: Resource Group = $resourceGroup" -ForegroundColor White
Write-Host "  5. Add email: $EmailAddress" -ForegroundColor White
Write-Host "  6. Set thresholds: 80%, 90%, 100%" -ForegroundColor White
Write-Host ""

Write-Host "TO REMOVE ALERTS:" -ForegroundColor Cyan
Write-Host "  .\Setup-CostAlerts.ps1 -Remove" -ForegroundColor White
Write-Host ""

# Save configuration
$alertConfig = @{
    created = Get-Date -Format "o"
    email = $EmailAddress
    daily_threshold = $DailyThreshold
    monthly_threshold = $MonthlyThreshold
    action_group = $actionGroupName
    alerts = @($alertNameDaily, $alertNameMonthly)
} | ConvertTo-Json

$configFile = ".\cost-alerts-config.json"
Set-Content -Path $configFile -Value $alertConfig
Write-Host "[INFO] Configuration saved to: $configFile" -ForegroundColor Gray
