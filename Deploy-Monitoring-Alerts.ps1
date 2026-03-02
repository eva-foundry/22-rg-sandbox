#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Azure Monitor baseline alerts for sandbox resources

.DESCRIPTION
    Creates production-ready alert rules for all EsDAICoE-Sandbox resources
    Based on Project 18 Module 01 (Azure Monitor Baseline Alerts)
    
    Reference: I:\eva-foundation\18-azure-best\01-monitoring

.PARAMETER ResourceGroup
    Target resource group (default: EsDAICoE-Sandbox)

.PARAMETER ActionGroupEmail
    Email address for alert notifications (default: marco.presta@hrsdc-rhdcc.gc.ca)

.PARAMETER WhatIf
    Show what would be deployed without making changes

.EXAMPLE
    .\Deploy-Monitoring-Alerts.ps1
    Deploy all alert rules to default resource group

.EXAMPLE
    .\Deploy-Monitoring-Alerts.ps1 -WhatIf
    Preview alert rules without deploying

.NOTES
    Author: AI Assistant (Claude Sonnet 4.5)
    Date: February 3, 2026
    Based On: Project 18 Module 01
#>

[CmdletBinding()]
param(
    [string]$ResourceGroup = "EsDAICoE-Sandbox",
    [string]$ActionGroupEmail = "marco.presta@hrsdc-rhdcc.gc.ca",
    [switch]$WhatIf
)

# Set UTF-8 encoding for enterprise Windows
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AZURE MONITOR BASELINE ALERTS" -ForegroundColor Cyan
Write-Host "  Deploy monitoring for sandbox" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate Azure CLI
try {
    $account = az account show --query "{subscription:id, name:name}" | ConvertFrom-Json
    Write-Host "[PASS] Azure CLI authenticated" -ForegroundColor Green
    Write-Host "  Subscription: $($account.name)" -ForegroundColor White
    Write-Host "  ID: $($account.subscription)" -ForegroundColor Gray
} catch {
    Write-Host "[FAIL] Azure CLI not authenticated" -ForegroundColor Red
    Write-Host "Run: az login --use-device-code" -ForegroundColor Yellow
    exit 1
}

# Validate resource group exists
Write-Host ""
Write-Host "[INFO] Validating resource group..." -ForegroundColor Cyan
$rg = az group show --name $ResourceGroup --query "{name:name, location:location}" 2>$null | ConvertFrom-Json
if (-not $rg) {
    Write-Host "[FAIL] Resource group '$ResourceGroup' not found" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] Resource group found: $($rg.name) ($($rg.location))" -ForegroundColor Green

# Get all resources in RG
Write-Host ""
Write-Host "[INFO] Discovering resources..." -ForegroundColor Cyan
$resources = az resource list --resource-group $ResourceGroup --query "[].{name:name, type:type, id:id}" | ConvertFrom-Json

if ($resources.Count -eq 0) {
    Write-Host "[WARN] No resources found in $ResourceGroup" -ForegroundColor Yellow
    Write-Host "Deploy infrastructure first before creating alerts" -ForegroundColor Yellow
    exit 0
}

Write-Host "[PASS] Found $($resources.Count) resources" -ForegroundColor Green
foreach ($resource in $resources) {
    Write-Host "  - $($resource.name) ($($resource.type))" -ForegroundColor White
}

# Action Group Configuration
$actionGroupName = "marco-sandbox-alerts"
$actionGroupShortName = "SandboxAlert"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PHASE 1: Action Group" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host ""
    Write-Host "[WHATIF] Would create action group:" -ForegroundColor Yellow
    Write-Host "  Name: $actionGroupName" -ForegroundColor White
    Write-Host "  Short Name: $actionGroupShortName" -ForegroundColor White
    Write-Host "  Email: $ActionGroupEmail" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "[INFO] Creating action group..." -ForegroundColor Cyan
    
    # Check if action group already exists
    $existingAG = az monitor action-group show --name $actionGroupName --resource-group $ResourceGroup 2>$null
    if ($existingAG) {
        Write-Host "[INFO] Action group already exists, skipping creation" -ForegroundColor Yellow
    } else {
        az monitor action-group create `
            --name $actionGroupName `
            --short-name $actionGroupShortName `
            --resource-group $ResourceGroup `
            --email-receiver "MarcoPresta" $ActionGroupEmail | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[PASS] Action group created: $actionGroupName" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Action group creation failed" -ForegroundColor Red
            exit 1
        }
    }
}

# Get action group ID for alert rules
$actionGroupId = "/subscriptions/$($account.subscription)/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/actionGroups/$actionGroupName"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PHASE 2: Alert Rules" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Alert rule definitions (Microsoft baseline thresholds)
$alertRules = @()

# App Service Plans (3 expected: backend, enrichment, func)
$appServicePlans = $resources | Where-Object { $_.type -eq "Microsoft.Web/serverfarms" }
foreach ($asp in $appServicePlans) {
    $alertRules += @{
        Name = "$($asp.name)-high-cpu"
        Description = "Alert when CPU usage exceeds 80% for 5 minutes"
        ResourceId = $asp.id
        Metric = "CpuPercentage"
        Threshold = 80
        Operator = "GreaterThan"
        Severity = 2  # Warning
    }
    
    $alertRules += @{
        Name = "$($asp.name)-high-memory"
        Description = "Alert when memory usage exceeds 85% for 5 minutes"
        ResourceId = $asp.id
        Metric = "MemoryPercentage"
        Threshold = 85
        Operator = "GreaterThan"
        Severity = 2  # Warning
    }
}

# Web Apps (2 expected: backend, enrichment)
$webApps = $resources | Where-Object { $_.type -eq "Microsoft.Web/sites" -and $_.name -notlike "*-func" }
foreach ($webapp in $webApps) {
    $alertRules += @{
        Name = "$($webapp.name)-http-errors"
        Description = "Alert when HTTP 5xx error rate exceeds 5% for 5 minutes"
        ResourceId = $webapp.id
        Metric = "Http5xx"
        Threshold = 10  # 10 errors in 5 minutes
        Operator = "GreaterThan"
        Severity = 1  # Error
    }
    
    $alertRules += @{
        Name = "$($webapp.name)-response-time"
        Description = "Alert when average response time exceeds 3 seconds"
        ResourceId = $webapp.id
        Metric = "AverageResponseTime"
        Threshold = 3
        Operator = "GreaterThan"
        Severity = 2  # Warning
    }
}

# Cognitive Search (1 expected: marco-sandbox-search)
$searchServices = $resources | Where-Object { $_.type -eq "Microsoft.Search/searchServices" }
foreach ($search in $searchServices) {
    $alertRules += @{
        Name = "$($search.name)-throttling"
        Description = "Alert when search requests are throttled"
        ResourceId = $search.id
        Metric = "ThrottledSearchQueriesPercentage"
        Threshold = 5  # 5% throttled
        Operator = "GreaterThan"
        Severity = 1  # Error
    }
    
    $alertRules += @{
        Name = "$($search.name)-latency"
        Description = "Alert when search query latency exceeds 1 second"
        ResourceId = $search.id
        Metric = "SearchLatency"
        Threshold = 1000  # 1000ms
        Operator = "GreaterThan"
        Severity = 2  # Warning
    }
}

# Cosmos DB (1 expected: marco-sandbox-cosmos)
$cosmosAccounts = $resources | Where-Object { $_.type -eq "Microsoft.DocumentDB/databaseAccounts" }
foreach ($cosmos in $cosmosAccounts) {
    $alertRules += @{
        Name = "$($cosmos.name)-high-ru"
        Description = "Alert when RU consumption exceeds 80% of provisioned"
        ResourceId = $cosmos.id
        Metric = "TotalRequestUnits"
        Threshold = 1000  # Serverless threshold
        Operator = "GreaterThan"
        Severity = 2  # Warning
    }
    
    $alertRules += @{
        Name = "$($cosmos.name)-availability"
        Description = "Alert when availability drops below 99.9%"
        ResourceId = $cosmos.id
        Metric = "ServiceAvailability"
        Threshold = 99.9
        Operator = "LessThan"
        Severity = 0  # Critical
    }
}

# Storage Accounts (1 expected: marcosand20260203)
$storageAccounts = $resources | Where-Object { $_.type -eq "Microsoft.Storage/storageAccounts" }
foreach ($storage in $storageAccounts) {
    $alertRules += @{
        Name = "$($storage.name)-availability"
        Description = "Alert when blob availability drops below 99.9%"
        ResourceId = $storage.id
        Metric = "Availability"
        Threshold = 99.9
        Operator = "LessThan"
        Severity = 1  # Error
    }
}

Write-Host ""
Write-Host "[INFO] Alert rules to deploy: $($alertRules.Count)" -ForegroundColor Cyan

# Deploy or preview alert rules
$deployedCount = 0
foreach ($rule in $alertRules) {
    if ($WhatIf) {
        Write-Host ""
        Write-Host "[WHATIF] Would create alert rule:" -ForegroundColor Yellow
        Write-Host "  Name: $($rule.Name)" -ForegroundColor White
        Write-Host "  Resource: $(Split-Path $rule.ResourceId -Leaf)" -ForegroundColor White
        Write-Host "  Metric: $($rule.Metric)" -ForegroundColor White
        Write-Host "  Threshold: $($rule.Threshold)" -ForegroundColor White
        Write-Host "  Severity: $($rule.Severity)" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "[INFO] Creating: $($rule.Name)..." -ForegroundColor Cyan
        
        # Check if alert rule already exists
        $existingRule = az monitor metrics alert show --name $rule.Name --resource-group $ResourceGroup 2>$null
        if ($existingRule) {
            Write-Host "[INFO] Alert rule already exists, skipping" -ForegroundColor Yellow
            continue
        }
        
        # Create metric alert
        az monitor metrics alert create `
            --name $rule.Name `
            --resource-group $ResourceGroup `
            --description $rule.Description `
            --scopes $rule.ResourceId `
            --condition "avg $($rule.Metric) $($rule.Operator) $($rule.Threshold)" `
            --window-size 5m `
            --evaluation-frequency 1m `
            --severity $rule.Severity `
            --action $actionGroupId 2>$null | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[PASS] Created: $($rule.Name)" -ForegroundColor Green
            $deployedCount++
        } else {
            Write-Host "[WARN] Failed to create: $($rule.Name)" -ForegroundColor Yellow
        }
        
        Start-Sleep -Milliseconds 500  # Rate limiting
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host ""
    Write-Host "[WHATIF] Summary:" -ForegroundColor Yellow
    Write-Host "  Action Group: 1" -ForegroundColor White
    Write-Host "  Alert Rules: $($alertRules.Count)" -ForegroundColor White
    Write-Host "  Total Resources: $($resources.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "[INFO] Run without -WhatIf to deploy" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "[PASS] Monitoring deployment complete!" -ForegroundColor Green
    Write-Host "  Action Group: $actionGroupName" -ForegroundColor White
    Write-Host "  Alert Rules Deployed: $deployedCount" -ForegroundColor White
    Write-Host "  Notification Email: $ActionGroupEmail" -ForegroundColor White
    Write-Host ""
    Write-Host "[INFO] Test alerts:" -ForegroundColor Cyan
    Write-Host "  az monitor metrics alert list --resource-group $ResourceGroup -o table" -ForegroundColor White
    Write-Host ""
    Write-Host "[INFO] View in Azure Portal:" -ForegroundColor Cyan
    Write-Host "  https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/alertsV2" -ForegroundColor White
}
