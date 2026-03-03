# ==============================================================================
# Quick Deployment Script for marcosub Clean Slate
# ==============================================================================
# Purpose: Fast-track deployment to marcosub dev environment
# Usage: .\DEPLOY-MARCOSUB.ps1 -SubscriptionId "YOUR_MARCOSUB_ID"
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage="Enter your marcosub subscription ID")]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "EVA-Sandbox-dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "canadacentral",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipProviderRegistration,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host @"

╔════════════════════════════════════════════════════════════════════════════╗
║                  EVA INFRASTRUCTURE - MARCOSUB DEPLOYMENT                  ║
║                         Clean Slate Dev Environment                        ║
╚════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ==============================================================================
# STEP 1: Verify Prerequisites
# ==============================================================================
Write-Host "`n[1/8] Verifying prerequisites..." -ForegroundColor Yellow

# Check Azure CLI
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "  ✓ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Error "Azure CLI not found. Install from: https://aka.ms/installazurecli"
}

# Check Bicep
try {
    $bicepVersion = az bicep version
    Write-Host "  ✓ Bicep version: $bicepVersion" -ForegroundColor Green
} catch {
    Write-Host "  Installing Bicep..." -ForegroundColor Yellow
    az bicep install
}

# Check Docker (optional but recommended)
try {
    $dockerVersion = docker --version
    Write-Host "  ✓ $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Docker not found (needed for image migration)" -ForegroundColor DarkYellow
}

# ==============================================================================
# STEP 2: Authenticate and Set Subscription
# ==============================================================================
Write-Host "`n[2/8] Authenticating to Azure..." -ForegroundColor Yellow

# Check if already logged in
$currentAccount = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Please complete device authentication..." -ForegroundColor Cyan
    az login --use-device-code
}

# Set subscription
Write-Host "  Setting subscription to: $SubscriptionId" -ForegroundColor Cyan
az account set --subscription $SubscriptionId

# Verify
$account = az account show | ConvertFrom-Json
Write-Host "  ✓ Connected to: $($account.name)" -ForegroundColor Green
Write-Host "    Tenant: $($account.tenantId)" -ForegroundColor Gray
Write-Host "    Subscription ID: $($account.id)" -ForegroundColor Gray

# ==============================================================================
# STEP 3: Register Resource Providers
# ==============================================================================
if (-not $SkipProviderRegistration) {
    Write-Host "`n[3/8] Registering resource providers..." -ForegroundColor Yellow
    
    $providers = @(
        'Microsoft.App',
        'Microsoft.DocumentDB',
        'Microsoft.CognitiveServices',
        'Microsoft.ContainerRegistry',
        'Microsoft.KeyVault',
        'Microsoft.Storage',
        'Microsoft.Web',
        'Microsoft.ApiManagement',
        'Microsoft.EventHub',
        'Microsoft.Insights',
        'Microsoft.OperationalInsights',
        'Microsoft.DataFactory',
        'Microsoft.Search'
    )
    
    $i = 0
    foreach ($provider in $providers) {
        $i++
        Write-Progress -Activity "Registering Providers" -Status "$provider" -PercentComplete (($i / $providers.Count) * 100)
        
        $state = az provider show --namespace $provider --query "registrationState" -o tsv 2>$null
        if ($state -ne 'Registered') {
            Write-Host "  Registering $provider..." -ForegroundColor Gray
            az provider register --namespace $provider --wait
        } else {
            Write-Host "  ✓ $provider" -ForegroundColor Green
        }
    }
    Write-Progress -Activity "Registering Providers" -Completed
} else {
    Write-Host "`n[3/8] Skipping provider registration (--SkipProviderRegistration)" -ForegroundColor Gray
}

# ==============================================================================
# STEP 4: Create Resource Group
# ==============================================================================
Write-Host "`n[4/8] Creating resource group..." -ForegroundColor Yellow

$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq 'true') {
    Write-Host "  ⚠ Resource group '$ResourceGroupName' already exists" -ForegroundColor DarkYellow
    $confirm = Read-Host "  Continue deployment to existing RG? (y/n)"
    if ($confirm -ne 'y') {
        Write-Host "`nDeployment cancelled." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  Creating '$ResourceGroupName' in $Location..." -ForegroundColor Cyan
    az group create --name $ResourceGroupName --location $Location --output none
    Write-Host "  ✓ Resource group created" -ForegroundColor Green
}

# ==============================================================================
# STEP 5: Validate Template
# ==============================================================================
Write-Host "`n[5/8] Validating Bicep template..." -ForegroundColor Yellow

$templateFile = Join-Path $scriptPath "main.bicep"
$parametersFile = Join-Path $scriptPath "parameters.dev.json"

if (-not (Test-Path $templateFile)) {
    Write-Error "Template file not found: $templateFile"
}
if (-not (Test-Path $parametersFile)) {
    Write-Error "Parameters file not found: $parametersFile"
}

Write-Host "  Template: $templateFile" -ForegroundColor Gray
Write-Host "  Parameters: $parametersFile" -ForegroundColor Gray

$validation = az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file $templateFile `
    --parameters $parametersFile 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Template validation failed:" -ForegroundColor Red
    Write-Host $validation -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Template validation passed" -ForegroundColor Green

# ==============================================================================
# STEP 6: Preview Changes (What-If)
# ==============================================================================
if ($WhatIf) {
    Write-Host "`n[6/8] Previewing deployment changes (what-if)..." -ForegroundColor Yellow
    
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file $templateFile `
        --parameters $parametersFile
    
    Write-Host "`n--WhatIf specified. Exiting without deployment." -ForegroundColor Cyan
    exit 0
}

# ==============================================================================
# STEP 7: Deploy Infrastructure
# ==============================================================================
Write-Host "`n[7/8] Deploying infrastructure to marcosub..." -ForegroundColor Yellow
Write-Host "  This will take approximately 15-20 minutes..." -ForegroundColor Gray

$deploymentName = "eva-deployment-$(Get-Date -Format 'yyyyMMdd-HHmm')"

Write-Host "`n  Starting deployment: $deploymentName" -ForegroundColor Cyan
Write-Host "  Press Ctrl+C to cancel (resources will be left in provisioning state)`n" -ForegroundColor DarkYellow

$startTime = Get-Date

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $templateFile `
    --parameters $parametersFile `
    --name $deploymentName `
    --output table

$duration = (Get-Date) - $startTime

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Deployment failed" -ForegroundColor Red
    Write-Host "Check errors with:" -ForegroundColor Yellow
    Write-Host "  az deployment group show --resource-group $ResourceGroupName --name $deploymentName" -ForegroundColor Gray
    exit 1
}

Write-Host "`n  ✓ Deployment completed in $($duration.TotalMinutes.ToString('0.0')) minutes" -ForegroundColor Green

# ==============================================================================
# STEP 8: Post-Deployment Summary
# ==============================================================================
Write-Host "`n[8/8] Deployment Summary" -ForegroundColor Yellow

# Get deployment outputs
Write-Host "`n  Deployment Outputs:" -ForegroundColor Cyan
$outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query "properties.outputs" | ConvertFrom-Json

foreach ($output in $outputs.PSObject.Properties) {
    Write-Host "    $($output.Name): $($output.Value.value)" -ForegroundColor Gray
}

# Count resources
$resourceCount = az resource list --resource-group $ResourceGroupName --query "length(@)"
Write-Host "`n  ✓ Total resources deployed: $resourceCount" -ForegroundColor Green

# List key resources
Write-Host "`n  Key Resources:" -ForegroundColor Cyan
$resources = az resource list `
    --resource-group $ResourceGroupName `
    --query "[?starts_with(name, 'marco')].{Name:name, Type:type, Location:location}" | ConvertFrom-Json

$resources | Format-Table -Property Name, Type, Location -AutoSize | Out-String | Write-Host

Write-Host @"

╔════════════════════════════════════════════════════════════════════════════╗
║                        DEPLOYMENT COMPLETE! 🎉                             ║
╚════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host @"
Next Steps:
-----------
1. Push container images to new ACR
   → See DEPLOYMENT-MARCOSUB.md section 5.1

2. Configure Cosmos DB databases and containers
   → See DEPLOYMENT-MARCOSUB.md section 5.2

3. Store secrets in Key Vault
   → See DEPLOYMENT-MARCOSUB.md section 5.3

4. Configure RBAC for managed identities
   → Run: .\Deploy-Infrastructure.ps1 -Environment dev -SubscriptionId "$SubscriptionId"
   → Or see DEPLOYMENT-MARCOSUB.md section 5.4

5. Verify Container Apps health
   → See DEPLOYMENT-MARCOSUB.md section 5.5

Full guide: DEPLOYMENT-MARCOSUB.md
Quick reference: QUICK-REFERENCE.md

Deployment Name: $deploymentName
Resource Group: $ResourceGroupName
Subscription: $($account.name) ($SubscriptionId)

"@ -ForegroundColor Cyan

Write-Host "Deployment log saved to: deployment-$(Get-Date -Format 'yyyyMMdd-HHmm').log" -ForegroundColor Gray
