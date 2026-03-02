# EVA-FEATURE: F22-02
# EVA-STORY: F22-02-001
# EVA-STORY: F22-03-001
# EVA-STORY: F22-04-001
# EVA-STORY: F22-04-002
# EVA-STORY: F22-04-003
# EVA-STORY: F22-05-001
# EVA-STORY: F22-05-002
# EVA-STORY: F22-06-001
# EVA-STORY: F22-06-002
# EVA-STORY: F22-06-003
# EVA-STORY: F22-06-004
# EVA-STORY: F22-06-005
# EVA-STORY: F22-07-001
# EVA-STORY: F22-07-002
# EVA-STORY: F22-07-003
# EVA-STORY: F22-07-004
# EVA-STORY: F22-08-001
# EVA-STORY: F22-08-002
# EVA-STORY: F22-09-001
# EVA-STORY: F22-09-002
# EVA-STORY: F22-09-003
# EVA-STORY: F22-09-004
# EVA-STORY: F22-09-005
# EVA-STORY: F22-10-001
# EVA-STORY: F22-10-002
# EVA-STORY: F22-10-003
# EVA-STORY: F22-12-001
# EVA-STORY: F22-12-002
# EVA-STORY: F22-12-003
# Enhanced Storage Assessment Script for EsDAICoE-Sandbox
# Version: 2.0
# Purpose: Comprehensive storage inventory with copy planning and validation
# Date: February 4, 2026
# Author: GitHub Copilot + Marco Presta

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "EsDAICoE-Sandbox",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\assessments",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDev2Assessment,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateCopyCommands,
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckPermissions,
    
    [Parameter(Mandatory=$false)]
    [int]$RetryAttempts = 3,
    
    [Parameter(Mandatory=$false)]
    [int]$RetryDelaySeconds = 5
)

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"  # Suppress progress bars for cleaner output

# Initialize logging
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $OutputDir $timestamp
$logFile = Join-Path $outputPath "assessment-log.txt"

# Create output directory
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "DEBUG"   { "Gray" }
        default   { "White" }
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $color
    
    # File output
    Add-Content -Path $logFile -Value $logMessage
}

# Retry wrapper for Azure CLI commands
function Invoke-AzCommandWithRetry {
    param(
        [string]$Command,
        [int]$MaxRetries = $RetryAttempts,
        [int]$DelaySeconds = $RetryDelaySeconds
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Log "Executing: $Command" -Level "DEBUG"
            $result = Invoke-Expression $Command 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                return $result
            } else {
                throw "Command failed with exit code $LASTEXITCODE"
            }
        }
        catch {
            if ($attempt -lt $MaxRetries) {
                Write-Log "Attempt $attempt failed: $($_.Exception.Message). Retrying in $DelaySeconds seconds..." -Level "WARN"
                Start-Sleep -Seconds $DelaySeconds
                $attempt++
            } else {
                Write-Log "All $MaxRetries attempts failed: $($_.Exception.Message)" -Level "ERROR"
                throw
            }
        }
    }
}

# Check prerequisites
function Test-Prerequisites {
    Write-Log "Checking prerequisites..." -Level "INFO"
    
    # Check Azure CLI
    try {
        $azVersion = az version --output json 2>&1 | ConvertFrom-Json
        Write-Log "Azure CLI version: $($azVersion.'azure-cli')" -Level "SUCCESS"
    }
    catch {
        Write-Log "Azure CLI not found or not working. Please install: https://aka.ms/installazurecliwindows" -Level "ERROR"
        return $false
    }
    
    # Check if logged in
    try {
        $account = az account show --output json 2>&1 | ConvertFrom-Json
        Write-Log "Logged in as: $($account.user.name)" -Level "SUCCESS"
    }
    catch {
        Write-Log "Not logged in to Azure CLI. Run: az login" -Level "ERROR"
        return $false
    }
    
    # Check subscription access
    try {
        $subscription = az account show --subscription $SubscriptionId --output json 2>&1 | ConvertFrom-Json
        Write-Log "Subscription access verified: $($subscription.name)" -Level "SUCCESS"
    }
    catch {
        Write-Log "Cannot access subscription $SubscriptionId. Check permissions." -Level "ERROR"
        return $false
    }
    
    # Check resource group exists
    try {
        $rg = az group show --name $ResourceGroup --subscription $SubscriptionId --output json 2>&1 | ConvertFrom-Json
        Write-Log "Resource group found: $($rg.name) in $($rg.location)" -Level "SUCCESS"
    }
    catch {
        Write-Log "Resource group $ResourceGroup not found in subscription" -Level "ERROR"
        return $false
    }
    
    return $true
}

# Check RBAC permissions
function Test-StoragePermissions {
    param([string]$StorageAccountName)
    
    if (-not $CheckPermissions) {
        return $true
    }
    
    Write-Log "Checking permissions for: $StorageAccountName" -Level "INFO"
    
    try {
        # Get current user's object ID
        $currentUser = az ad signed-in-user show --output json 2>&1 | ConvertFrom-Json
        $userObjectId = $currentUser.id
        
        # Check role assignments
        $roleAssignmentsJson = az role assignment list `
            --assignee $userObjectId `
            --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts/$StorageAccountName" `
            --output json 2>&1
        
        $roleAssignments = $roleAssignmentsJson | ConvertFrom-Json
        
        $hasReadAccess = $roleAssignments | Where-Object { 
            $_.roleDefinitionName -match "Storage Blob Data Reader|Storage Blob Data Contributor|Storage Blob Data Owner|Owner|Contributor"
        }
        
        if ($hasReadAccess) {
            Write-Log "Permissions OK: User has blob data access" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Limited permissions: May not be able to list blobs" -Level "WARN"
            return $false
        }
    }
    catch {
        Write-Log "Could not check permissions: $($_.Exception.Message)" -Level "WARN"
        return $true  # Don't block on permission check failure
    }
}

# Assess single storage account
function Get-StorageAccountAssessment {
    param(
        [object]$StorageAccount,
        [int]$Index,
        [int]$Total
    )
    
    Write-Log "[$Index/$Total] Assessing: $($StorageAccount.name)" -Level "INFO"
    
    # Build assessment with safe property access
    $assessment = [PSCustomObject]@{
        name = if ($StorageAccount.name) { $StorageAccount.name } else { "Unknown" }
        location = if ($StorageAccount.location) { $StorageAccount.location } else { "Unknown" }
        sku = if ($StorageAccount.sku) { $StorageAccount.sku.name } else { "Unknown" }
        kind = if ($StorageAccount.kind) { $StorageAccount.kind } else { "Unknown" }
        createdTime = if ($StorageAccount.creationTime) { $StorageAccount.creationTime } else { "Unknown" }
        primaryEndpoints = if ($StorageAccount.primaryEndpoints) { $StorageAccount.primaryEndpoints } else { @{} }
        containers = @()
        totalSizeGB = 0
        totalBlobCount = 0
        accessTier = if ($StorageAccount.accessTier) { $StorageAccount.accessTier } else { "Unknown" }
        allowBlobPublicAccess = if ($null -ne $StorageAccount.allowBlobPublicAccess) { $StorageAccount.allowBlobPublicAccess } else { $false }
        networkRuleSet = [PSCustomObject]@{
            defaultAction = if ($StorageAccount.networkRuleSet) { $StorageAccount.networkRuleSet.defaultAction } else { "Unknown" }
            bypass = if ($StorageAccount.networkRuleSet) { $StorageAccount.networkRuleSet.bypass } else { "Unknown" }
            ipRules = if ($StorageAccount.networkRuleSet.ipRules) { $StorageAccount.networkRuleSet.ipRules.Count } else { 0 }
            virtualNetworkRules = if ($StorageAccount.networkRuleSet.virtualNetworkRules) { $StorageAccount.networkRuleSet.virtualNetworkRules.Count } else { 0 }
        }
        supportsHttpsTrafficOnly = if ($null -ne $StorageAccount.enableHttpsTrafficOnly) { $StorageAccount.enableHttpsTrafficOnly } else { $false }
        minimumTlsVersion = if ($StorageAccount.minimumTlsVersion) { $StorageAccount.minimumTlsVersion } else { "Unknown" }
        hasPermissions = $false
        errors = @()
    }
    
    # Check permissions
    $assessment.hasPermissions = Test-StoragePermissions -StorageAccountName $StorageAccount.name
    
    try {
        # Get storage account key
        $keysJson = Invoke-AzCommandWithRetry -Command "az storage account keys list --account-name $($StorageAccount.name) --resource-group $ResourceGroup --subscription $SubscriptionId --output json"
        $keys = $keysJson | ConvertFrom-Json
        
        if (-not $keys -or $keys.Count -eq 0) {
            $assessment.errors += "No access keys available"
            Write-Log "No access keys for $($StorageAccount.name)" -Level "WARN"
            return $assessment
        }
        
        $accountKey = $keys[0].value
        
        # List containers
        $containersJson = Invoke-AzCommandWithRetry -Command "az storage container list --account-name $($StorageAccount.name) --account-key '$accountKey' --output json"
        $containers = $containersJson | ConvertFrom-Json
        
        if (-not $containers) {
            Write-Log "No containers found (storage account may be empty)" -Level "INFO"
            return $assessment
        }
        
        Write-Log "Found $($containers.Count) container(s)" -Level "INFO"
        
        # Assess each container
        foreach ($container in $containers) {
            Write-Log "  Assessing container: $($container.name)" -Level "DEBUG"
            
            try {
                # List blobs
                $blobListJson = Invoke-AzCommandWithRetry -Command "az storage blob list --container-name '$($container.name)' --account-name $($StorageAccount.name) --account-key '$accountKey' --output json"
                $blobs = $blobListJson | ConvertFrom-Json
                
                if (-not $blobs) {
                    $blobs = @()
                }
                
                $blobCount = $blobs.Count
                $containerSizeBytes = 0
                if ($blobCount -gt 0) {
                    $containerSizeBytes = ($blobs | ForEach-Object { 
                        if ($_.properties.contentLength) { 
                            [long]$_.properties.contentLength 
                        } else { 
                            0 
                        } 
                    } | Measure-Object -Sum).Sum
                }
                
                if (-not $containerSizeBytes) {
                    $containerSizeBytes = 0
                }
                
                $containerSizeGB = [math]::Round($containerSizeBytes / 1GB, 3)
                
                # Get sample blob names
                $sampleBlobs = $blobs | Select-Object -First 5 | ForEach-Object { $_.name }
                
                # Get blob types breakdown
                $blobTypes = $blobs | Group-Object -Property { if ($_.properties.blobType) { $_.properties.blobType } else { "Unknown" } } | ForEach-Object {
                    @{ Type = $_.Name; Count = $_.Count }
                }
                
                $containerAssessment = [PSCustomObject]@{
                    name = $container.name
                    blobCount = $blobCount
                    sizeBytes = $containerSizeBytes
                    sizeGB = $containerSizeGB
                    publicAccess = if ($container.properties.publicAccess) { $container.properties.publicAccess } else { "None" }
                    lastModified = if ($container.properties.lastModified) { $container.properties.lastModified } else { "Unknown" }
                    leaseStatus = if ($container.properties.lease.status) { $container.properties.lease.status } else { "Unknown" }
                    sampleBlobs = $sampleBlobs
                    blobTypes = $blobTypes
                }
                
                $assessment.containers += $containerAssessment
                $assessment.totalSizeGB += $containerSizeGB
                $assessment.totalBlobCount += $blobCount
                
                Write-Log "  Container $($container.name): $blobCount blobs, $containerSizeGB GB" -Level "SUCCESS"
            }
            catch {
                $assessment.errors += "Container $($container.name): $($_.Exception.Message)"
                Write-Log "  Failed to assess container $($container.name): $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
    catch {
        $assessment.errors += "Storage account assessment failed: $($_.Exception.Message)"
        Write-Log "Failed to assess storage account: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $assessment
}

# Generate copy commands
function New-CopyCommandScript {
    param([array]$StorageAssessments)
    
    if (-not $GenerateCopyCommands) {
        return
    }
    
    Write-Log "Generating copy command script..." -Level "INFO"
    
    $scriptPath = Join-Path $outputPath "Copy-StorageContent.ps1"
    
    $script = @"
# Storage Copy Commands - Generated $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Review and customize before execution

param(
    [Parameter(Mandatory=`$true)]
    [string]`$SourceStorageAccount,
    
    [Parameter(Mandatory=`$true)]
    [string]`$SourceKey,
    
    [Parameter(Mandatory=`$false)]
    [string]`$DestinationStorageAccount = "marcosand20260203",
    
    [Parameter(Mandatory=`$false)]
    [string]`$DestinationKey,
    
    [Parameter(Mandatory=`$false)]
    [switch]`$DryRun
)

# Get destination key if not provided
if (-not `$DestinationKey) {
    `$keysJson = az storage account keys list --account-name `$DestinationStorageAccount --resource-group "$ResourceGroup" --output json
    `$keys = `$keysJson | ConvertFrom-Json
    `$DestinationKey = `$keys[0].value
}

"@
    
    foreach ($storage in $StorageAssessments) {
        if ($storage.containers.Count -eq 0) {
            continue
        }
        
        $script += @"

# ========================================
# Copy from: $($storage.name)
# Total: $($storage.totalBlobCount) blobs, $($storage.totalSizeGB) GB
# ========================================

"@
        
        foreach ($container in $storage.containers) {
            $script += @"

Write-Host "[INFO] Copying container: $($container.name) ($($container.blobCount) blobs, $($container.sizeGB) GB)" -ForegroundColor Cyan

if (`$DryRun) {
    Write-Host "[DRY RUN] Would copy from $($storage.name)/$($container.name) to `$DestinationStorageAccount/$($container.name)" -ForegroundColor Yellow
} else {
    # Create destination container if not exists
    az storage container create \``
        --name "$($container.name)" \``
        --account-name `$DestinationStorageAccount \``
        --account-key `$DestinationKey
    
    # Copy blobs (using AzCopy for better performance)
    `$sourceUrl = "https://$($storage.name).blob.core.windows.net/$($container.name)"
    `$destUrl = "https://`$DestinationStorageAccount.blob.core.windows.net/$($container.name)"
    
    azcopy copy "`$sourceUrl?`$SourceKey" "`$destUrl?`$DestinationKey" --recursive
}

"@
        }
    }
    
    $script | Out-File $scriptPath -Encoding UTF8
    Write-Log "Copy command script saved: $scriptPath" -Level "SUCCESS"
}

# Main execution
Write-Log "========================================" -Level "INFO"
Write-Log "Storage Assessment Script v2.0" -Level "INFO"
Write-Log "========================================" -Level "INFO"
Write-Log "Subscription: $SubscriptionId" -Level "INFO"
Write-Log "Resource Group: $ResourceGroup" -Level "INFO"
Write-Log "Output Directory: $outputPath" -Level "INFO"
Write-Log "" -Level "INFO"

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisites check failed. Exiting." -Level "ERROR"
    exit 1
}

Write-Log "" -Level "INFO"

# Set subscription context
Write-Log "Setting Azure subscription context..." -Level "INFO"
try {
    Invoke-AzCommandWithRetry -Command "az account set --subscription $SubscriptionId"
    Write-Log "Subscription context set successfully" -Level "SUCCESS"
}
catch {
    Write-Log "Failed to set subscription context: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

Write-Log "" -Level "INFO"

# List storage accounts
Write-Log "Listing storage accounts in $ResourceGroup..." -Level "INFO"
try {
    $storageAccountsJson = Invoke-AzCommandWithRetry -Command "az storage account list --resource-group $ResourceGroup --subscription $SubscriptionId --output json"
    $storageAccounts = $storageAccountsJson | ConvertFrom-Json
    
    Write-Log "Found $($storageAccounts.Count) storage account(s)" -Level "SUCCESS"
}
catch {
    Write-Log "Failed to list storage accounts: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# Save raw storage accounts list
$storageAccountsFile = Join-Path $outputPath "storage-accounts.json"
$storageAccounts | ConvertTo-Json -Depth 10 | Out-File $storageAccountsFile
Write-Log "Storage accounts list saved: $storageAccountsFile" -Level "SUCCESS"

Write-Log "" -Level "INFO"

# Assess each storage account
$assessments = @()
$index = 1
foreach ($storage in $storageAccounts) {
    $assessment = Get-StorageAccountAssessment -StorageAccount $storage -Index $index -Total $storageAccounts.Count
    $assessments += $assessment
    $index++
    Write-Log "" -Level "INFO"
}

# Save complete assessment
$totalSize = ($assessments | ForEach-Object { if ($_.totalSizeGB) { $_.totalSizeGB } else { 0 } } | Measure-Object -Sum).Sum
$totalBlobs = ($assessments | ForEach-Object { if ($_.totalBlobCount) { $_.totalBlobCount } else { 0 } } | Measure-Object -Sum).Sum

$assessmentData = [PSCustomObject]@{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    subscription = $SubscriptionId
    resourceGroup = $ResourceGroup
    storageAccountCount = $storageAccounts.Count
    totalSizeGB = $totalSize
    totalBlobCount = $totalBlobs
    storageAccounts = $assessments
}

$assessmentFile = Join-Path $outputPath "storage-assessment.json"
$assessmentData | ConvertTo-Json -Depth 10 | Out-File $assessmentFile
Write-Log "Complete assessment saved: $assessmentFile" -Level "SUCCESS"

Write-Log "" -Level "INFO"

# Generate copy commands if requested
New-CopyCommandScript -StorageAssessments $assessments

# Generate markdown report
Write-Log "Generating summary report..." -Level "INFO"

$reportFile = Join-Path $outputPath "STORAGE-ASSESSMENT-SUMMARY.md"
$report = @"
# Storage Assessment Report - EsDAICoE-Sandbox

**Assessment Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Subscription**: EsDAICoESub ($SubscriptionId)  
**Resource Group**: $ResourceGroup  
**Storage Accounts Found**: $($storageAccounts.Count)  
**Total Size**: $([math]::Round($assessmentData.totalSizeGB, 2)) GB  
**Total Blobs**: $($assessmentData.totalBlobCount)

---

## Executive Summary

"@

$emptyAccounts = $assessments | Where-Object { $_.containers.Count -eq 0 }
$populatedAccounts = $assessments | Where-Object { $_.containers.Count -gt 0 }
$totalContainers = ($assessments | ForEach-Object { $_.containers.Count } | Measure-Object -Sum).Sum

$report += @"

**Storage Status**:
- **Empty**: $($emptyAccounts.Count) storage account(s)
- **Contains Data**: $($populatedAccounts.Count) storage account(s)
- **Total Containers**: $totalContainers

"@

$totalErrors = ($assessments | ForEach-Object { $_.errors.Count } | Measure-Object -Sum).Sum
if ($totalErrors -gt 0) {
    $report += @"

**Errors Encountered**: $totalErrors

"@
}

$report += @"

---

## Storage Accounts Detail

"@

foreach ($sa in $assessments) {
    $statusIcon = if ($sa.containers.Count -eq 0) { "[EMPTY]" } else { "[DATA]" }
    $report += @"

### $statusIcon Storage Account: $($sa.name)

**Configuration**:
- **SKU**: $($sa.sku) | **Kind**: $($sa.kind) | **Location**: $($sa.location)
- **Created**: $($sa.createdTime)
- **Access Tier**: $($sa.accessTier)
- **Public Blob Access**: $($sa.allowBlobPublicAccess)
- **HTTPS Only**: $($sa.supportsHttpsTrafficOnly)
- **Min TLS Version**: $($sa.minimumTlsVersion)

**Network Security**:
- **Default Action**: $($sa.networkRuleSet.defaultAction)
- **Bypass**: $($sa.networkRuleSet.bypass)
- **IP Rules**: $($sa.networkRuleSet.ipRules)
- **VNet Rules**: $($sa.networkRuleSet.virtualNetworkRules)

**Storage Summary**:
- **Total Size**: $($sa.totalSizeGB) GB
- **Total Blobs**: $($sa.totalBlobCount)
- **Containers**: $($sa.containers.Count)
- **Has Permissions**: $($sa.hasPermissions)

"@

    if ($sa.containers.Count -gt 0) {
        $report += @"

**Container Breakdown**:

| Container | Blobs | Size (GB) | Public Access | Last Modified |
|-----------|-------|-----------|---------------|---------------|
"@
        
        foreach ($container in $sa.containers) {
            $report += "`n| $($container.name) | $($container.blobCount) | $($container.sizeGB) | $($container.publicAccess) | $($container.lastModified) |"
        }
        
        $report += "`n`n"
        
        # Add sample blobs
        foreach ($container in $sa.containers) {
            if ($container.sampleBlobs -and @($container.sampleBlobs).Count -gt 0) {
                $report += @"

**Sample Blobs in $($container.name)**:
"@
                foreach ($blob in $container.sampleBlobs) {
                    $report += "`n- ``$blob``"
                }
                $report += "`n`n"
            }
        }
    }
    
    if ($sa.errors.Count -gt 0) {
        $report += @"

**Errors**:
"@
        foreach ($error in $sa.errors) {
            $report += "`n- $error"
        }
        $report += "`n`n"
    }
}

$report += @"

---

## Copy Plan Template

### Source Identification

| Source Storage | Source Container | Content Type | Size (GB) | Blob Count |
|----------------|------------------|--------------|-----------|------------|

"@

foreach ($sa in $populatedAccounts) {
    foreach ($container in $sa.containers) {
        $report += "| $($sa.name) | $($container.name) | [TO FILL] | $($container.sizeGB) | $($container.blobCount) |`n"
    }
}

$report += @"

### Destination Mapping

| From (Source) | To (Destination) | Container | Priority | Notes |
|---------------|------------------|-----------|----------|-------|
| [SOURCE_STORAGE] | marcosand20260203 | [CONTAINER] | High | [PURPOSE] |

### Copy Method Recommendations

**For containers < 1 GB**:
``````powershell
# Use az storage blob copy
az storage blob copy start-batch \`
  --source-account-name [SOURCE] \`
  --source-container [CONTAINER] \`
  --destination-account-name marcosand20260203 \`
  --destination-container [CONTAINER] \`
  --pattern "*"
``````

**For containers > 1 GB**:
``````powershell
# Use AzCopy for better performance
azcopy copy \`
  "https://[SOURCE].blob.core.windows.net/[CONTAINER]?[SAS_TOKEN]" \`
  "https://marcosand20260203.blob.core.windows.net/[CONTAINER]?[SAS_TOKEN]" \`
  --recursive
``````

---

## Next Steps

**Immediate Actions**:
1. [ ] Review this assessment report
2. [ ] Identify content sources (Dev2, external, sample data?)
3. [ ] Fill out the Copy Plan Template above
4. [ ] Verify access permissions on source and destination
5. [ ] Test copy with small sample before bulk copy
6. [ ] Execute copy operations (use generated script if available)
7. [ ] Validate copied content

**Prerequisites Before Copy**:
- [ ] Source storage account identified
- [ ] Access keys or SAS tokens obtained
- [ ] Network connectivity verified (private endpoints, firewalls)
- [ ] Destination containers created
- [ ] RBAC permissions validated (Storage Blob Data Contributor)
- [ ] Estimated copy time calculated
- [ ] Backup plan defined (if overwriting existing data)

---

**Assessment Files**:
- **JSON Data**: $assessmentFile
- **Storage List**: $storageAccountsFile
- **This Report**: $reportFile
"@

if ($GenerateCopyCommands -and $populatedAccounts.Count -gt 0) {
    $report += "`n- **Copy Script**: $(Join-Path $outputPath 'Copy-StorageContent.ps1')`n"
}

$report += @"

**Log File**: $logFile

---

*Assessment completed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")*

"@

$report | Out-File $reportFile -Encoding UTF8
Write-Log "Summary report saved: $reportFile" -Level "SUCCESS"

Write-Log "" -Level "INFO"

# Display summary
Write-Log "========================================" -Level "INFO"
Write-Log "ASSESSMENT COMPLETE" -Level "SUCCESS"
Write-Log "========================================" -Level "INFO"
Write-Log "" -Level "INFO"

foreach ($sa in $assessments) {
    $status = if ($sa.containers.Count -eq 0) { "[EMPTY]" } else { "[DATA]" }
    Write-Log "$status $($sa.name): $($sa.containers.Count) containers, $($sa.totalBlobCount) blobs, $($sa.totalSizeGB) GB" -Level "INFO"
}

Write-Log "" -Level "INFO"
Write-Log "Output Directory: $outputPath" -Level "INFO"
Write-Log "Summary Report: $reportFile" -Level "INFO"

if ($GenerateCopyCommands -and $populatedAccounts.Count -gt 0) {
    Write-Log "Copy Script: $(Join-Path $outputPath 'Copy-StorageContent.ps1')" -Level "INFO"
}

Write-Log "" -Level "INFO"
Write-Log "[NEXT] Review the summary report and complete the copy plan" -Level "INFO"
Write-Log "========================================" -Level "INFO"
