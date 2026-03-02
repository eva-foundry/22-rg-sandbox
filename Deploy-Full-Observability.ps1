#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy complete sandbox with APIM + FinOps (Option A - Full Observability)

.DESCRIPTION
    Orchestrates 3-phase deployment:
    - Phase 1: Base RAG system (12 resources, 122/month)
    - Phase 2: APIM gateway (50/month)
    - Phase 3: FinOps Hub (65/month)
    
    Total: 237/month with full cost tracking and analytics

.PARAMETER Phase
    Deployment phase: Base, APIM, FinOps, or All

.PARAMETER WhatIf
    Preview deployment without creating resources

.EXAMPLE
    .\Deploy-Full-Observability.ps1 -WhatIf
    Preview all 3 phases

.EXAMPLE
    .\Deploy-Full-Observability.ps1 -Phase All
    Deploy everything (15-25 minutes base + 15-20 min APIM + 5-10 min FinOps)

.EXAMPLE
    .\Deploy-Full-Observability.ps1 -Phase APIM
    Deploy only APIM (assumes base already deployed)
#>

[CmdletBinding()]
param(
    [ValidateSet("Base", "APIM", "FinOps", "All")]
    [string]$Phase = "All",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Set encoding for Windows enterprise
$env:PYTHONIOENCODING = "utf-8"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OPTION A: FULL OBSERVABILITY DEPLOYMENT" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[DEPLOYMENT PLAN]" -ForegroundColor Yellow
Write-Host "Phase 1: Base RAG System" -ForegroundColor White
Write-Host "  - 12 resources (Search, Cosmos, Storage, Web Apps, Functions)" -ForegroundColor Gray
Write-Host "  - Cost: `$122/month" -ForegroundColor Gray
Write-Host "  - Time: 15-25 minutes" -ForegroundColor Gray
Write-Host ""
Write-Host "Phase 2: APIM Gateway" -ForegroundColor White
Write-Host "  - API Management Developer SKU" -ForegroundColor Gray
Write-Host "  - Rate limiting + JWT validation" -ForegroundColor Gray
Write-Host "  - Cost: +`$50/month" -ForegroundColor Gray
Write-Host "  - Time: 15-20 minutes" -ForegroundColor Gray
Write-Host ""
Write-Host "Phase 3: FinOps Hub" -ForegroundColor White
Write-Host "  - Storage Account (Data Lake)" -ForegroundColor Gray
Write-Host "  - Data Factory (ingestion)" -ForegroundColor Gray
Write-Host "  - Cost Management exports" -ForegroundColor Gray
Write-Host "  - Cost: +`$65/month" -ForegroundColor Gray
Write-Host "  - Time: 5-10 minutes" -ForegroundColor Gray
Write-Host ""
Write-Host "TOTAL COST: `$237/month" -ForegroundColor Cyan
Write-Host "TOTAL TIME: 35-55 minutes" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF MODE] Preview only - no resources created" -ForegroundColor Yellow
    Write-Host ""
}

# Configuration
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$resourceGroup = "EsDAICoE-Sandbox"
$deploymentStart = Get-Date

# Phase execution tracking
$phaseResults = @{
    Base = @{Deployed = $false; Duration = $null; Error = $null}
    APIM = @{Deployed = $false; Duration = $null; Error = $null}
    FinOps = @{Deployed = $false; Duration = $null; Error = $null}
}

# ============================================================================
# PHASE 1: BASE RAG SYSTEM
# ============================================================================

if ($Phase -in @("Base", "All")) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PHASE 1: BASE RAG SYSTEM" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $phase1Start = Get-Date
    
    try {
        if ($WhatIf) {
            & "$PSScriptRoot\Deploy-Sandbox-AzCLI.ps1" -WhatIf
        } else {
            & "$PSScriptRoot\Deploy-Sandbox-AzCLI.ps1"
        }
        
        $phaseResults.Base.Deployed = $true
        $phaseResults.Base.Duration = ((Get-Date) - $phase1Start).TotalMinutes
        
        Write-Host ""
        Write-Host "[PHASE 1 COMPLETE] Duration: $([math]::Round($phaseResults.Base.Duration, 1)) minutes" -ForegroundColor Green
        Write-Host ""
    } catch {
        $phaseResults.Base.Error = $_.Exception.Message
        Write-Host ""
        Write-Host "[PHASE 1 FAILED] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        
        if ($Phase -eq "All") {
            Write-Host "[ABORT] Cannot continue to Phase 2 without base system" -ForegroundColor Red
            exit 1
        } else {
            exit 1
        }
    }
}

# ============================================================================
# PHASE 2: APIM GATEWAY
# ============================================================================

if ($Phase -in @("APIM", "All")) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PHASE 2: APIM GATEWAY" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Verify base deployment exists
    if (-not $WhatIf -and $Phase -eq "APIM") {
        Write-Host "[INFO] Verifying base deployment exists..." -ForegroundColor Gray
        
        # Check for Cosmos DB instead (more reliable)
        $cosmosExists = az cosmosdb show `
            --name "marco-sandbox-cosmos" `
            --resource-group $resourceGroup `
            --query 'id' -o tsv 2>$null
        
        if (-not $cosmosExists) {
            Write-Host "[ERROR] Base deployment not found. Deploy base first:" -ForegroundColor Red
            Write-Host "  .\Deploy-Full-Observability.ps1 -Phase Base" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "[PASS] Base deployment verified" -ForegroundColor Green
        Write-Host ""
    }
    
    $phase2Start = Get-Date
    
    try {
        if ($WhatIf) {
            & "$PSScriptRoot\Deploy-APIM.ps1" -WhatIf
        } else {
            & "$PSScriptRoot\Deploy-APIM.ps1"
        }
        
        $phaseResults.APIM.Deployed = $true
        $phaseResults.APIM.Duration = ((Get-Date) - $phase2Start).TotalMinutes
        
        Write-Host ""
        Write-Host "[PHASE 2 COMPLETE] Duration: $([math]::Round($phaseResults.APIM.Duration, 1)) minutes" -ForegroundColor Green
        Write-Host ""
    } catch {
        $phaseResults.APIM.Error = $_.Exception.Message
        Write-Host ""
        Write-Host "[PHASE 2 FAILED] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[INFO] You can retry APIM deployment later: .\Deploy-APIM.ps1" -ForegroundColor Yellow
        Write-Host ""
        
        if ($Phase -eq "All") {
            Write-Host "[WARNING] Continuing to Phase 3 despite APIM failure..." -ForegroundColor Yellow
        } else {
            exit 1
        }
    }
}

# ============================================================================
# PHASE 3: FINOPS HUB
# ============================================================================

if ($Phase -in @("FinOps", "All")) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PHASE 3: FINOPS HUB" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $phase3Start = Get-Date
    
    try {
        if ($WhatIf) {
            & "$PSScriptRoot\Deploy-FinOpsHub-Sandbox.ps1" -WhatIf
        } else {
            & "$PSScriptRoot\Deploy-FinOpsHub-Sandbox.ps1"
        }
        
        $phaseResults.FinOps.Deployed = $true
        $phaseResults.FinOps.Duration = ((Get-Date) - $phase3Start).TotalMinutes
        
        Write-Host ""
        Write-Host "[PHASE 3 COMPLETE] Duration: $([math]::Round($phaseResults.FinOps.Duration, 1)) minutes" -ForegroundColor Green
        Write-Host ""
    } catch {
        $phaseResults.FinOps.Error = $_.Exception.Message
        Write-Host ""
        Write-Host "[PHASE 3 FAILED] $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[INFO] You can retry FinOps deployment later: .\Deploy-FinOpsHub-Sandbox.ps1" -ForegroundColor Yellow
        Write-Host ""
        
        if ($Phase -ne "All") {
            exit 1
        }
    }
}

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

$deploymentDuration = ((Get-Date) - $deploymentStart).TotalMinutes

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[PHASES DEPLOYED]" -ForegroundColor Yellow
foreach ($phaseName in @("Base", "APIM", "FinOps")) {
    $result = $phaseResults[$phaseName]
    
    if ($result.Deployed) {
        Write-Host "  [PASS] $phaseName - $([math]::Round($result.Duration, 1)) minutes" -ForegroundColor Green
    } elseif ($result.Error) {
        Write-Host "  [FAIL] $phaseName - $($result.Error)" -ForegroundColor Red
    } else {
        Write-Host "  [SKIP] $phaseName - Not requested" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Total Duration: $([math]::Round($deploymentDuration, 1)) minutes" -ForegroundColor Cyan
Write-Host ""

# Calculate monthly cost
$monthlyCost = 0
if ($phaseResults.Base.Deployed) { $monthlyCost += 122 }
if ($phaseResults.APIM.Deployed) { $monthlyCost += 50 }
if ($phaseResults.FinOps.Deployed) { $monthlyCost += 65 }

Write-Host "[MONTHLY COST]" -ForegroundColor Yellow
if ($phaseResults.Base.Deployed) {
    Write-Host "  Base RAG System: `$122/month" -ForegroundColor White
}
if ($phaseResults.APIM.Deployed) {
    Write-Host "  APIM Gateway: `$50/month" -ForegroundColor White
}
if ($phaseResults.FinOps.Deployed) {
    Write-Host "  FinOps Hub: `$65/month" -ForegroundColor White
}
Write-Host "  TOTAL: `$$monthlyCost/month" -ForegroundColor Cyan
Write-Host ""

# Post-deployment steps
if ($phaseResults.Base.Deployed -or $phaseResults.APIM.Deployed -or $phaseResults.FinOps.Deployed) {
    Write-Host "[POST-DEPLOYMENT STEPS]" -ForegroundColor Yellow
    Write-Host ""
    
    if ($phaseResults.Base.Deployed) {
        Write-Host "1. Configure backend application settings:" -ForegroundColor White
        Write-Host "   - Upload backend code to App Service" -ForegroundColor Gray
        Write-Host "   - Configure environment variables" -ForegroundColor Gray
        Write-Host "   - Test health endpoint: https://marco-sandbox-backend.azurewebsites.net/health" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($phaseResults.APIM.Deployed) {
        Write-Host "2. Configure APIM authentication:" -ForegroundColor White
        Write-Host "   - Create Entra ID app registration" -ForegroundColor Gray
        Write-Host "   - Update JWT validation policy with app ID" -ForegroundColor Gray
        Write-Host "   - Test API through APIM gateway" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($phaseResults.FinOps.Deployed) {
        Write-Host "3. Configure cost tracking:" -ForegroundColor White
        Write-Host "   - Run: .\Configure-CostTracking.ps1" -ForegroundColor Gray
        Write-Host "   - Wait 5-10 minutes for first cost export" -ForegroundColor Gray
        Write-Host "   - Verify data in Storage Account" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "4. Set up Power BI dashboards:" -ForegroundColor White
    Write-Host "   - Download FinOps Toolkit templates" -ForegroundColor Gray
    Write-Host "   - Connect to storage account: marcosandboxfinopshub" -ForegroundColor Gray
    Write-Host "   - Import KQL queries from: powerbi-kql-queries.txt" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "5. Test end-to-end flow:" -ForegroundColor White
    Write-Host "   - Upload document via frontend" -ForegroundColor Gray
    Write-Host "   - Ask question and get RAG response" -ForegroundColor Gray
    Write-Host "   - Verify cost tracking in App Insights" -ForegroundColor Gray
    Write-Host "   - Check APIM logs" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "[USEFUL LINKS]" -ForegroundColor Yellow
Write-Host "Azure Portal:" -ForegroundColor White
Write-Host "  https://portal.azure.com/#@bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8/resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup" -ForegroundColor Cyan
Write-Host ""
if ($phaseResults.APIM.Deployed) {
    Write-Host "APIM Gateway:" -ForegroundColor White
    Write-Host "  https://marco-sandbox-apim.azure-api.net" -ForegroundColor Cyan
    Write-Host ""
}
Write-Host "Application Insights:" -ForegroundColor White
Write-Host "  https://portal.azure.com/#@bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8/resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/microsoft.insights/components/marco-sandbox-appinsights" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Exit with appropriate code
if ($phaseResults.Base.Error -or $phaseResults.APIM.Error -or $phaseResults.FinOps.Error) {
    exit 1
} else {
    exit 0
}
