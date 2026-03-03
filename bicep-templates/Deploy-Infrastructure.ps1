# ==============================================================================
# Marco EVA Sandbox - Automated Deployment Script
# ==============================================================================
# Purpose: Automate end-to-end deployment of EVA infrastructure to Azure
# Version: 1.0.0
# Last Updated: 2026-03-03
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "EVA-Sandbox-$Environment",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = 'canadacentral',
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPostDeployment
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n[STEP] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

# ==============================================================================
# PREREQUISITES CHECK
# ==============================================================================

Write-Step "Checking prerequisites..."

# Check Azure CLI
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Success "Azure CLI version: $($azVersion.'azure-cli')"
} catch {
    Write-Failure "Azure CLI not found. Install from https://aka.ms/installazurecliwindows"
    exit 1
}

# Check Bicep CLI
try {
    $bicepVersion = az bicep version
    Write-Success "Bicep version: $bicepVersion"
} catch {
    Write-Info "Bicep not found, installing..."
    az bicep install
}

# Check logged in
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-Success "Logged in as: $($account.user.name)"
} catch {
    Write-Info "Not logged in, initiating login..."
    az login --use-device-code
    $account = az account show --output json | ConvertFrom-Json
}

# Set subscription if provided
if ($SubscriptionId) {
    Write-Info "Setting subscription to: $SubscriptionId"
    az account set --subscription $SubscriptionId
    $account = az account show --output json | ConvertFrom-Json
}

Write-Success "Using subscription: $($account.name) ($($account.id))"

# ==============================================================================
# VALIDATE TEMPLATES
# ==============================================================================

if (-not $SkipValidation) {
    Write-Step "Validating Bicep templates..."
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
    $templatePath = Join-Path $PSScriptRoot "main.bicep"
    $parametersPath = Join-Path $PSScriptRoot "parameters.$Environment.json"
    
    if (-not (Test-Path $templatePath)) {
        Write-Failure "Template not found: $templatePath"
        exit 1
    }
    
    if (-not (Test-Path $parametersPath)) {
        Write-Failure "Parameters file not found: $parametersPath"
        exit 1
    }
    
    # Create resource group if it doesn't exist
    $rgExists = az group exists --name $ResourceGroupName
    if ($rgExists -eq 'false') {
        Write-Info "Creating resource group: $ResourceGroupName"
        az group create --name $ResourceGroupName --location $Location
    }
    
    # Validate deployment
    Write-Info "Validating template syntax and parameters..."
    $validation = az deployment group validate `
        --resource-group $ResourceGroupName `
        --template-file $templatePath `
        --parameters $parametersPath `
        --parameters deploymentTimestamp=$timestamp `
        --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Failure "Validation failed:`n$validation"
        exit 1
    }
    
    Write-Success "Template validation passed"
}

# ==============================================================================
# WHAT-IF ANALYSIS
# ==============================================================================

if ($WhatIf) {
    Write-Step "Running what-if analysis..."
    
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file $templatePath `
        --parameters $parametersPath `
        --parameters deploymentTimestamp=$timestamp `
        --no-pretty-print
    
    Write-Info "What-if analysis complete. Use -WhatIf:`$false to proceed with deployment."
    exit 0
}

# ==============================================================================
# DEPLOY INFRASTRUCTURE
# ==============================================================================

Write-Step "Deploying infrastructure to resource group: $ResourceGroupName"
Write-Info "Environment: $Environment"
Write-Info "Location: $Location"
Write-Info "Estimated time: 30-45 minutes"

$deploymentName = "eva-sandbox-deployment-$timestamp"

Write-Info "Starting deployment: $deploymentName"

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $templatePath `
    --parameters $parametersPath `
    --parameters deploymentTimestamp=$timestamp `
    --name $deploymentName `
    --verbose

if ($LASTEXITCODE -ne 0) {
    Write-Failure "Deployment failed. Check Azure Portal for details."
    exit 1
}

Write-Success "Infrastructure deployment complete!"

# ==============================================================================
# CAPTURE OUTPUTS
# ==============================================================================

Write-Step "Capturing deployment outputs..."

$outputsPath = Join-Path $PSScriptRoot "deployment-outputs-$timestamp.json"

az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query properties.outputs `
    --output json > $outputsPath

Write-Success "Outputs saved to: $outputsPath"

# Parse outputs
$outputs = Get-Content $outputsPath | ConvertFrom-Json

Write-Host "`n=== DEPLOYMENT OUTPUTS ===" -ForegroundColor Cyan
Write-Host "Container Registry: $($outputs.containerRegistryLoginServer.value)"
Write-Host "Cosmos DB Endpoint: $($outputs.cosmosDbEndpoint.value)"
Write-Host "Key Vault: $($outputs.keyVaultUri.value)"
Write-Host "EVA Brain API: https://$($outputs.brainApiFqdn.value)"
Write-Host "EVA Data Model API: https://$($outputs.dataModelApiFqdn.value)"
Write-Host "EVA Faces: https://$($outputs.facesFqdn.value)"
Write-Host "EVA Roles API: https://$($outputs.rolesApiFqdn.value)"
Write-Host "API Management: $($outputs.apimGatewayUrl.value)"
Write-Host "========================`n"

# ==============================================================================
# POST-DEPLOYMENT CONFIGURATION
# ==============================================================================

if (-not $SkipPostDeployment) {
    Write-Step "Running post-deployment configuration..."
    
    # 1. Configure RBAC for Container Apps -> ACR
    Write-Info "Configuring RBAC for Container Registry..."
    
    $acrName = $outputs.containerRegistryName.value
    $acrId = "/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerRegistry/registries/$acrName"
    
    $containerApps = @(
        "marco-eva-brain-api",
        "marco-eva-data-model",
        "marco-eva-faces",
        "marco-eva-roles-api"
    )
    
    foreach ($appName in $containerApps) {
        $principalId = az containerapp show `
            --resource-group $ResourceGroupName `
            --name $appName `
            --query identity.principalId `
            --output tsv 2>$null
        
        if ($principalId) {
            Write-Info "Granting AcrPull to $appName..."
            az role assignment create `
                --assignee $principalId `
                --role AcrPull `
                --scope $acrId `
                --output none 2>$null
        }
    }
    
    Write-Success "RBAC configuration complete"
    
    # 2. Configure Key Vault access
    Write-Info "Configuring Key Vault access..."
    
    $kvName = $outputs.keyVaultName.value
    $kvId = "/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$kvName"
    
    foreach ($appName in $containerApps) {
        $principalId = az containerapp show `
            --resource-group $ResourceGroupName `
            --name $appName `
            --query identity.principalId `
            --output tsv 2>$null
        
        if ($principalId) {
            Write-Info "Granting Key Vault Secrets User to $appName..."
            az role assignment create `
                --assignee $principalId `
                --role "Key Vault Secrets User" `
                --scope $kvId `
                --output none 2>$null
        }
    }
    
    Write-Success "Key Vault access configured"
    
    # 3. Store critical secrets in Key Vault
    Write-Info "Storing secrets in Key Vault..."
    
    $cosmosEndpoint = $outputs.cosmosDbEndpoint.value
    az keyvault secret set `
        --vault-name $kvName `
        --name "COSMOS-ENDPOINT" `
        --value $cosmosEndpoint `
        --output none 2>$null
    
    Write-Success "Secrets stored in Key Vault"
    
    # 4. Verify Container App health
    Write-Info "Verifying Container App health..."
    
    Start-Sleep -Seconds 30  # Allow apps to start
    
    foreach ($appName in $containerApps) {
        $fqdn = az containerapp show `
            --resource-group $ResourceGroupName `
            --name $appName `
            --query properties.configuration.ingress.fqdn `
            --output tsv 2>$null
        
        if ($fqdn) {
            try {
                $response = Invoke-WebRequest -Uri "https://$fqdn/health" -TimeoutSec 10 -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    Write-Success "$appName is healthy"
                } else {
                    Write-Info "$appName returned status: $($response.StatusCode)"
                }
            } catch {
                Write-Info "$appName health check failed (may not be ready yet)"
            }
        }
    }
}

# ==============================================================================
# SUMMARY
# ==============================================================================

Write-Host "`n=== DEPLOYMENT SUMMARY ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment"
Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Deployment Name: $deploymentName"
Write-Host "Status: COMPLETE"
Write-Host "Outputs File: $outputsPath"
Write-Host "`nNext Steps:"
Write-Host "1. Push container images to ACR: $($outputs.containerRegistryLoginServer.value)"
Write-Host "2. Configure Cosmos DB databases and containers"
Write-Host "3. Import APIs into API Management"
Write-Host "4. Test all endpoints"
Write-Host "`nSee README.md for detailed post-deployment steps."
Write-Host "=========================`n"

Write-Success "Deployment complete! 🎉"
