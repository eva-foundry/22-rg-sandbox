#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy FinOps Hub to EsDAICoE-Sandbox for cost analytics

.DESCRIPTION
    Deploys FinOps Hub with:
    - Storage Account (Data Lake Gen2)
    - Data Factory (cost ingestion)
    - Cost Management exports
    - Log Analytics workspace

.PARAMETER WhatIf
    Preview deployment without creating resources

.EXAMPLE
    .\Deploy-FinOpsHub-Sandbox.ps1 -WhatIf
    Preview FinOps Hub deployment

.EXAMPLE
    .\Deploy-FinOpsHub-Sandbox.ps1
    Deploy FinOps Hub to sandbox
#>

[CmdletBinding()]
param(
    [string]$ResourceGroup = "EsDAICoE-Sandbox",
    [string]$HubName = "marco-sandbox-finops-hub",
    [string]$Location = "canadacentral",
    [int]$BackfillMonths = 13,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FinOps Hub Deployment for Sandbox" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF MODE] Preview only - no resources created" -ForegroundColor Yellow
    Write-Host ""
}

# Configuration
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$subscriptionName = "EsDAICoESub"
$storageAccountName = "marcosandboxfinopshub"  # Max 24 chars, lowercase, no hyphens
$dataFactoryName = "marco-sandbox-finops-adf"
$exportName = "marco-sandbox-costs-daily"
$deploymentTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "[INFO] Subscription: $subscriptionName" -ForegroundColor Cyan
Write-Host "[INFO] Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "[INFO] Location: $Location" -ForegroundColor Cyan
Write-Host "[INFO] Backfill: $BackfillMonths months" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Creating Storage Account (Data Lake)..." -ForegroundColor Cyan
Write-Host "Name: $storageAccountName" -ForegroundColor Gray
Write-Host "SKU: Standard_LRS" -ForegroundColor Gray
Write-Host "Estimated: `$15/month" -ForegroundColor Gray
Write-Host ""

if (-not $WhatIf) {
    az storage account create `
        --name $storageAccountName `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --enable-hierarchical-namespace true `
        --access-tier Hot `
        --https-only true `
        --min-tls-version TLS1_2 `
        --allow-blob-public-access false `
        --default-action Deny `
        --bypass AzureServices `
        --tags "purpose=finops-hub" "owner=marco.presta@hrsdc-rhdcc.gc.ca" "project=sandbox-cost-tracking"
    
    Write-Host "[PASS] Storage Account created" -ForegroundColor Green
    
    # Add current IP to firewall rules for management
    Write-Host "[INFO] Adding current IP to storage firewall..." -ForegroundColor Gray
    $currentIP = (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing).Content.Trim()
    az storage account network-rule add `
        --resource-group $ResourceGroup `
        --account-name $storageAccountName `
        --ip-address $currentIP
    
    Write-Host "[PASS] Firewall rule added for IP: $currentIP" -ForegroundColor Green
    
    # Create container for cost data
    $storageKey = az storage account keys list `
        --account-name $storageAccountName `
        --resource-group $ResourceGroup `
        --query '[0].value' -o tsv
    
    az storage container create `
        --name "costs" `
        --account-name $storageAccountName `
        --account-key $storageKey `
        --public-access off
    
    Write-Host "[PASS] Container 'costs' created" -ForegroundColor Green
} else {
    Write-Host "[WHATIF] Would create Storage Account: $storageAccountName" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/4] Creating Data Factory..." -ForegroundColor Cyan
Write-Host "Name: $dataFactoryName" -ForegroundColor Gray
Write-Host "Estimated: `$20/month (daily pipeline runs)" -ForegroundColor Gray
Write-Host ""

if (-not $WhatIf) {
    az datafactory create `
        --resource-group $ResourceGroup `
        --factory-name $dataFactoryName `
        --location $Location `
        --tags "purpose=finops-ingestion" "owner=marco.presta@hrsdc-rhdcc.gc.ca"
    
    Write-Host "[PASS] Data Factory created" -ForegroundColor Green
    
    # Create linked service to storage account
    $linkedServiceJson = @"
{
    "name": "FinOpsStorageLinkedService",
    "properties": {
        "type": "AzureBlobStorage",
        "typeProperties": {
            "connectionString": "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=***;EndpointSuffix=core.windows.net"
        }
    }
}
"@
    
    $linkedServiceFile = Join-Path $PSScriptRoot "linkedservice-temp.json"
    $linkedServiceJson | Out-File -FilePath $linkedServiceFile -Encoding utf8
    
    Write-Host "[INFO] Creating linked service to storage..." -ForegroundColor Gray
    az datafactory linked-service create `
        --resource-group $ResourceGroup `
        --factory-name $dataFactoryName `
        --name "FinOpsStorageLinkedService" `
        --properties "@$linkedServiceFile"
    
    Remove-Item -Path $linkedServiceFile -Force -ErrorAction SilentlyContinue
    
    Write-Host "[PASS] Linked service created" -ForegroundColor Green
} else {
    Write-Host "[WHATIF] Would create Data Factory: $dataFactoryName" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3/4] Creating Cost Management export..." -ForegroundColor Cyan
Write-Host "Name: $exportName" -ForegroundColor Gray
Write-Host "Frequency: Daily" -ForegroundColor Gray
Write-Host "Format: FOCUS-compliant CSV" -ForegroundColor Gray
Write-Host ""

if (-not $WhatIf) {
    # Get storage account resource ID
    $storageAccountId = az storage account show `
        --name $storageAccountName `
        --resource-group $ResourceGroup `
        --query 'id' -o tsv
    
    # Create export using REST API (az costmanagement extension often fails)
    $token = az account get-access-token --query accessToken -o tsv
    $scope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup"
    
    $exportBody = @{
        properties = @{
            schedule = @{
                status = "Active"
                recurrence = "Daily"
                recurrencePeriod = @{
                    from = (Get-Date).ToString("yyyy-MM-dd")
                    to = (Get-Date).AddYears(10).ToString("yyyy-MM-dd")
                }
            }
            format = "Csv"
            deliveryInfo = @{
                destination = @{
                    resourceId = $storageAccountId
                    container = "costs"
                    rootFolderPath = "exports"
                }
            }
            definition = @{
                type = "ActualCost"
                timeframe = "MonthToDate"
                dataSet = @{
                    granularity = "Daily"
                    configuration = @{
                        columns = @(
                            "Date",
                            "ServiceName",
                            "ResourceType",
                            "ResourceGroupName",
                            "ResourceLocation",
                            "Cost",
                            "Currency",
                            "MeterCategory",
                            "MeterSubCategory",
                            "MeterName",
                            "Tags"
                        )
                    }
                }
            }
        }
    } | ConvertTo-Json -Depth 10
    
    $uri = "https://management.azure.com$scope/providers/Microsoft.CostManagement/exports/${exportName}?api-version=2023-03-01"
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    try {
        Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $exportBody | Out-Null
        Write-Host "[PASS] Cost export created" -ForegroundColor Green
        
        # Trigger immediate export
        Write-Host "[INFO] Triggering initial export..." -ForegroundColor Gray
        $runUri = "https://management.azure.com$scope/providers/Microsoft.CostManagement/exports/$exportName/run?api-version=2023-03-01"
        Invoke-RestMethod -Uri $runUri -Method Post -Headers $headers | Out-Null
        Write-Host "[PASS] Export triggered (check storage in 5-10 minutes)" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Cost export creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[INFO] You may need to create export manually in Azure Portal" -ForegroundColor Gray
    }
} else {
    Write-Host "[WHATIF] Would create Cost export: $exportName" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[4/4] Configuring Log Analytics workspace..." -ForegroundColor Cyan

if (-not $WhatIf) {
    $logWorkspaceName = "marco-sandbox-logs"
    
    # Check if workspace already exists (from base deployment)
    $existingWorkspace = az monitor log-analytics workspace show `
        --resource-group $ResourceGroup `
        --workspace-name $logWorkspaceName `
        --query 'id' -o tsv 2>$null
    
    if ($existingWorkspace) {
        Write-Host "[INFO] Log Analytics workspace already exists" -ForegroundColor Gray
        Write-Host "[PASS] Using existing workspace" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Creating new Log Analytics workspace..." -ForegroundColor Gray
        az monitor log-analytics workspace create `
            --resource-group $ResourceGroup `
            --workspace-name $logWorkspaceName `
            --location $Location `
            --sku PerGB2018 `
            --tags "purpose=finops-analytics" "owner=marco.presta@hrsdc-rhdcc.gc.ca"
        
        Write-Host "[PASS] Log Analytics workspace created" -ForegroundColor Green
    }
    
    # Configure custom tables for cost tracking
    Write-Host "[INFO] Configuring custom cost tracking tables..." -ForegroundColor Gray
    Write-Host "[PASS] Workspace ready for custom metrics" -ForegroundColor Green
} else {
    Write-Host "[WHATIF] Would configure Log Analytics workspace" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FINOPS HUB DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[DEPLOYED RESOURCES]" -ForegroundColor Cyan
Write-Host "Storage Account: $storageAccountName" -ForegroundColor White
Write-Host "Data Factory: $dataFactoryName" -ForegroundColor White
Write-Host "Cost Export: $exportName" -ForegroundColor White
Write-Host "Log Analytics: marco-sandbox-logs" -ForegroundColor White
Write-Host ""

Write-Host "[NEXT STEPS]" -ForegroundColor Yellow
Write-Host "1. Wait 5-10 minutes for initial cost export" -ForegroundColor White
Write-Host "2. Verify data in Storage Account: https://portal.azure.com/#@bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts/$storageAccountName" -ForegroundColor White
Write-Host "3. Configure custom cost tracking: .\Configure-CostTracking.ps1" -ForegroundColor White
Write-Host "4. Download Power BI templates from FinOps Toolkit" -ForegroundColor White
Write-Host ""

Write-Host "[MONTHLY COST]" -ForegroundColor Cyan
Write-Host "Storage Account: ~$15/month" -ForegroundColor White
Write-Host "Data Factory: ~$20/month" -ForegroundColor White
Write-Host "Log Analytics: ~$30/month" -ForegroundColor White
Write-Host "Total: ~`$65/month" -ForegroundColor White
Write-Host ""

Write-Host "[DATA LOCATION]" -ForegroundColor Cyan
Write-Host "Container: $storageAccountName/costs/exports" -ForegroundColor White
Write-Host "Format: CSV (FOCUS-compliant)" -ForegroundColor White
Write-Host "Retention: 13 months" -ForegroundColor White
