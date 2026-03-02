#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy API Management to EsDAICoE-Sandbox for cost tracking

.DESCRIPTION
    Deploys APIM Developer SKU with:
    - RAG API configuration
    - Rate limiting policies
    - Cost attribution headers
    - Application Insights integration

.PARAMETER WhatIf
    Preview deployment without creating resources

.EXAMPLE
    .\Deploy-APIM.ps1 -WhatIf
    Preview APIM deployment

.EXAMPLE
    .\Deploy-APIM.ps1
    Deploy APIM to sandbox
#>

[CmdletBinding()]
param(
    [string]$ResourceGroup = "EsDAICoE-Sandbox",
    [string]$ApimName = "marco-sandbox-apim",
    [string]$Location = "canadacentral",
    [string]$PublisherEmail = "marco.presta@hrsdc-rhdcc.gc.ca",
    [string]$PublisherName = "Marco Presta",
    [string]$Sku = "Developer",
    [string]$BackendUrl = "https://marco-sandbox-backend.azurewebsites.net",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "APIM Deployment for Sandbox Cost Tracking" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF MODE] Preview only - no resources created" -ForegroundColor Yellow
    Write-Host ""
}

# Configuration
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$apiName = "marco-sandbox-rag-api"
$apiVersion = "v1"
$deploymentTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host "[1/5] Creating APIM instance..." -ForegroundColor Cyan
Write-Host "[INFO] This takes 15-20 minutes for Developer SKU" -ForegroundColor Yellow
Write-Host "Resource: $ApimName" -ForegroundColor Gray
Write-Host "SKU: $Sku (`$50/month)" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host ""

if (-not $WhatIf) {
    az apim create `
        --name $ApimName `
        --resource-group $ResourceGroup `
        --location $Location `
        --publisher-email $PublisherEmail `
        --publisher-name $PublisherName `
        --sku-name $Sku `
        --no-wait
    
    Write-Host "[INFO] APIM creation started (background operation)" -ForegroundColor Green
    Write-Host "[INFO] Monitor progress: az apim show -n $ApimName -g $ResourceGroup --query 'provisioningState'" -ForegroundColor Gray
    Write-Host ""
    
    # Wait for APIM provisioning
    Write-Host "[INFO] Waiting for APIM to be ready..." -ForegroundColor Yellow
    $maxWaitMinutes = 25
    $waitStart = Get-Date
    
    while ($true) {
        $state = az apim show -n $ApimName -g $ResourceGroup --query 'provisioningState' -o tsv 2>$null
        $elapsed = ((Get-Date) - $waitStart).TotalMinutes
        
        if ($state -eq "Succeeded") {
            Write-Host "[PASS] APIM provisioned successfully" -ForegroundColor Green
            break
        } elseif ($elapsed -ge $maxWaitMinutes) {
            Write-Host "[WARN] Timeout waiting for APIM (${maxWaitMinutes}min). Check Azure Portal." -ForegroundColor Yellow
            Write-Host "[INFO] Continuing with API configuration..." -ForegroundColor Gray
            break
        } else {
            Write-Host "[INFO] State: $state (${elapsed:N1} min elapsed)" -ForegroundColor Gray
            Start-Sleep -Seconds 60
        }
    }
} else {
    Write-Host "[WHATIF] Would create APIM: $ApimName" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/5] Creating RAG API..." -ForegroundColor Cyan

if (-not $WhatIf) {
    # Create API
    az apim api create `
        --resource-group $ResourceGroup `
        --service-name $ApimName `
        --api-id $apiName `
        --display-name "Sandbox RAG API" `
        --path "/api/$apiVersion" `
        --protocols "https" `
        --service-url $BackendUrl
    
    Write-Host "[PASS] API created" -ForegroundColor Green
} else {
    Write-Host "[WHATIF] Would create API: $apiName" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3/5] Adding API operations..." -ForegroundColor Cyan

$operations = @(
    @{
        Name = "chat"
        Method = "POST"
        UrlTemplate = "/chat"
        Description = "RAG conversation endpoint"
    },
    @{
        Name = "upload"
        Method = "POST"
        UrlTemplate = "/upload"
        Description = "Document upload endpoint"
    },
    @{
        Name = "documents-list"
        Method = "GET"
        UrlTemplate = "/documents"
        Description = "List user documents"
    },
    @{
        Name = "health"
        Method = "GET"
        UrlTemplate = "/health"
        Description = "Health check endpoint"
    }
)

foreach ($op in $operations) {
    if (-not $WhatIf) {
        az apim api operation create `
            --resource-group $ResourceGroup `
            --service-name $ApimName `
            --api-id $apiName `
            --url-template $op.UrlTemplate `
            --method $op.Method `
            --display-name $op.Name `
            --description $op.Description
        
        Write-Host "[PASS] Operation: $($op.Method) $($op.UrlTemplate)" -ForegroundColor Green
    } else {
        Write-Host "[WHATIF] Would create: $($op.Method) $($op.UrlTemplate)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[4/5] Applying APIM policies..." -ForegroundColor Cyan

# Create policy XML
$policyXml = @"
<policies>
    <inbound>
        <!-- JWT Validation (Entra ID) -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
            <openid-config url="https://login.microsoftonline.com/bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8/.well-known/openid-configuration" />
            <required-claims>
                <claim name="aud">
                    <value>api://marco-sandbox-rag</value>
                </claim>
            </required-claims>
        </validate-jwt>
        
        <!-- Rate Limiting -->
        <rate-limit calls="100" renewal-period="60" />
        <quota calls="10000" renewal-period="86400" />
        
        <!-- Cost Attribution Headers -->
        <set-header name="X-User-Id" exists-action="override">
            <value>@(context.User.Id)</value>
        </set-header>
        <set-header name="X-Cost-Center" exists-action="override">
            <value>EsDAICoE-Sandbox</value>
        </set-header>
        <set-header name="X-Correlation-Id" exists-action="override">
            <value>@(Guid.NewGuid().ToString())</value>
        </set-header>
        
        <!-- Forward to backend -->
        <base />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <!-- Log to Application Insights -->
        <log-to-eventhub logger-id="appinsights-logger">
            @{
                return new JObject(
                    new JProperty("EventTime", DateTime.UtcNow.ToString()),
                    new JProperty("ServiceName", context.Deployment.ServiceName),
                    new JProperty("RequestId", context.RequestId),
                    new JProperty("RequestIp", context.Request.IpAddress),
                    new JProperty("OperationName", context.Operation.Name),
                    new JProperty("UserId", context.User.Id),
                    new JProperty("CostCenter", "EsDAICoE-Sandbox")
                ).ToString();
            }
        </log-to-eventhub>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
"@

$policyFile = Join-Path $PSScriptRoot "apim-policy-temp.xml"
$policyXml | Out-File -FilePath $policyFile -Encoding utf8

if (-not $WhatIf) {
    az apim api policy create `
        --resource-group $ResourceGroup `
        --service-name $ApimName `
        --api-id $apiName `
        --xml-content $policyXml
    
    Write-Host "[PASS] Policies applied" -ForegroundColor Green
    Write-Host "  - JWT validation (Entra ID)" -ForegroundColor Gray
    Write-Host "  - Rate limiting (100 calls/min)" -ForegroundColor Gray
    Write-Host "  - Cost attribution headers" -ForegroundColor Gray
    Write-Host "  - Application Insights logging" -ForegroundColor Gray
} else {
    Write-Host "[WHATIF] Would apply policies" -ForegroundColor Yellow
}

Remove-Item -Path $policyFile -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[5/5] Configuring Application Insights integration..." -ForegroundColor Cyan

if (-not $WhatIf) {
    # Get App Insights instrumentation key
    $appInsightsName = "marco-sandbox-appinsights"
    $instrumentationKey = az monitor app-insights component show `
        --app $appInsightsName `
        --resource-group $ResourceGroup `
        --query 'instrumentationKey' -o tsv 2>$null
    
    if ($instrumentationKey) {
        az apim logger create `
            --resource-group $ResourceGroup `
            --service-name $ApimName `
            --logger-id "appinsights-logger" `
            --logger-type "applicationInsights" `
            --description "Log APIM events to Application Insights" `
            --credentials "instrumentationKey=$instrumentationKey"
        
        Write-Host "[PASS] Application Insights integration configured" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Application Insights not found. Deploy base sandbox first." -ForegroundColor Yellow
    }
} else {
    Write-Host "[WHATIF] Would configure App Insights integration" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "APIM DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[NEXT STEPS]" -ForegroundColor Yellow
Write-Host "1. Update backend CORS to allow APIM origin" -ForegroundColor White
Write-Host "2. Configure Entra ID app registration for JWT validation" -ForegroundColor White
Write-Host "3. Deploy FinOps Hub: .\Deploy-FinOpsHub-Sandbox.ps1" -ForegroundColor White
Write-Host "4. Configure cost tracking: .\Configure-CostTracking.ps1" -ForegroundColor White
Write-Host ""

Write-Host "[APIM ENDPOINTS]" -ForegroundColor Cyan
Write-Host "Gateway: https://$ApimName.azure-api.net" -ForegroundColor White
Write-Host "Portal: https://$ApimName.portal.azure-api.net" -ForegroundColor White
Write-Host "Management: https://portal.azure.com/#@bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName" -ForegroundColor White
Write-Host ""

Write-Host "[MONTHLY COST]" -ForegroundColor Cyan
Write-Host "APIM Developer SKU: `$50/month" -ForegroundColor White
Write-Host "Application Insights: ~$20/month (logs)" -ForegroundColor White
Write-Host "Total: $70/month" -ForegroundColor White
