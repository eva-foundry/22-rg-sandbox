# Quick Start: FinOps Multi-Subscription Cost Collection

**Status**: ✅ Infrastructure Ready  
**Storage Account**: marcosandboxfinopshub (ADLS Gen2, Canada Central)  
**Next Step**: Configure cost exports (10 minutes)

---

## Option 1: Quick Start (Copy-Paste Script) ⚡

**Time**: 10 minutes  
**What it does**: Configure daily cost exports from EsDAICoESub and EsPAICoESub

```powershell
# === STEP 1: Get Storage Account Resource ID ===
az account set --subscription "EsDAICoESub"
$storageAccountId = az storage account show -n marcosandboxfinopshub -g EsDAICoE-Sandbox --query id -o tsv
Write-Host "Storage ID: $storageAccountId" -ForegroundColor Cyan

# === STEP 2: Create EsDAICoESub Export ===
az account set --subscription "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$token = az account get-access-token --query accessToken -o tsv
$scope = "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$exportName = "DailyCostExport-EsDAICoESub-FinOpsHub"
$uri = "https://management.azure.com${scope}/providers/Microsoft.CostManagement/exports/${exportName}?api-version=2023-08-01"

$exportBody = @{
    properties = @{
        schedule = @{
            status = "Active"
            recurrence = "Daily"
            recurrencePeriod = @{
                from = "2026-02-04T00:00:00Z"
                to = "2027-12-31T00:00:00Z"
            }
        }
        format = "Csv"
        deliveryInfo = @{
            destination = @{
                resourceId = $storageAccountId
                container = "costs"
                rootFolderPath = "esdaicoesub"
            }
        }
        definition = @{
            type = "ActualCost"
            timeframe = "MonthToDate"
            dataSet = @{
                granularity = "Daily"
            }
        }
        partitionData = $true
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $uri -Method PUT -Headers @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
} -Body $exportBody

Write-Host "[PASS] EsDAICoESub export configured" -ForegroundColor Green

# === STEP 3: Create EsPAICoESub Export ===
az account set --subscription "802d84ab-3189-4221-8453-fcc30c8dc8ea"
$token = az account get-access-token --query accessToken -o tsv
$scope = "/subscriptions/802d84ab-3189-4221-8453-fcc30c8dc8ea"
$exportName = "DailyCostExport-EsPAICoESub-FinOpsHub"
$uri = "https://management.azure.com${scope}/providers/Microsoft.CostManagement/exports/${exportName}?api-version=2023-08-01"

$exportBody = @{
    properties = @{
        schedule = @{
            status = "Active"
            recurrence = "Daily"
            recurrencePeriod = @{
                from = "2026-02-04T00:00:00Z"
                to = "2027-12-31T00:00:00Z"
            }
        }
        format = "Csv"
        deliveryInfo = @{
            destination = @{
                resourceId = $storageAccountId
                container = "costs"
                rootFolderPath = "espaicoesub"
            }
        }
        definition = @{
            type = "ActualCost"
            timeframe = "MonthToDate"
            dataSet = @{
                granularity = "Daily"
            }
        }
        partitionData = $true
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $uri -Method PUT -Headers @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
} -Body $exportBody

Write-Host "[PASS] EsPAICoESub export configured" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  COST EXPORTS CONFIGURED!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nExports will run daily at 00:00 UTC"
Write-Host "Next export: Tomorrow at midnight"
Write-Host "`nVerify in 24 hours:"
Write-Host "  az storage blob list --account-name marcosandboxfinopshub --container-name costs --auth-mode login" -ForegroundColor Yellow
```

---

## Option 2: Use Deployment Script

```powershell
cd I:\eva-foundation\22-rg-sandbox

# Deploy everything (cost exports + dashboards)
.\Deploy-FinOps-Complete.ps1

# Deploy exports only (skip historical backfill and Data Factory)
.\Deploy-FinOps-Complete.ps1 -SkipBackfill -SkipDataFactory
```

---

## Verification (15 minutes after export runs)

```powershell
# Check for exported files
az storage blob list `
    --account-name marcosandboxfinopshub `
    --container-name costs `
    --auth-mode login `
    --query "[].{Name:name, Size:properties.contentLength, LastModified:properties.lastModified}" `
    -o table
```

**Expected Output**:
```
Name                                                         Size      LastModified
------------------------------------------------------------ --------- ----------------------------
esdaicoesub/20260204-20260204/ActualCost_2026-02-04.csv    ~1-5 MB   2026-02-04T00:15:00+00:00
espaicoesub/20260204-20260204/ActualCost_2026-02-04.csv    ~500 KB   2026-02-04T00:15:00+00:00
```

---

## What Happens Next (Automatic)

1. **Tonight at Midnight UTC**: First exports run automatically
2. **00:15 UTC**: CSV files appear in marcosandboxfinopshub/costs/
3. **Tomorrow Morning**: You can analyze the data

---

## Quick Analysis Commands

**View EsDAICoESub costs**:
```powershell
az storage blob download `
    --account-name marcosandboxfinopshub `
    --container-name costs `
    --name "esdaicoesub/20260204-20260204/ActualCost_2026-02-04.csv" `
    --file "esdaicoesub-costs.csv" `
    --auth-mode login

# View in Excel or PowerShell
Import-Csv "esdaicoesub-costs.csv" | Select-Object -First 10
```

**Generate dashboard** (requires Python + Project 14 scripts):
```powershell
python Generate-MultiSub-Dashboard.py `
    --input "processed/daily-costs/" `
    --output "dashboard/multi-sub-costs-dashboard.html"

Start-Process "dashboard/multi-sub-costs-dashboard.html"
```

---

## Troubleshooting

**Export failed?**
```powershell
# Check export history
az account set --subscription "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$token = az account get-access-token --query accessToken -o tsv
$scope = "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$exportName = "DailyCostExport-EsDAICoESub-FinOpsHub"
$uri = "https://management.azure.com${scope}/providers/Microsoft.CostManagement/exports/${exportName}/runHistory?api-version=2023-08-01"

Invoke-RestMethod -Uri $uri -Method GET -Headers @{ Authorization = "Bearer $token" }
```

**No files appearing?**
- Wait 15-20 minutes after midnight UTC
- Check network rules: `az storage account show -n marcosandboxfinopshub -g EsDAICoE-Sandbox --query networkRuleSet`
- Ensure bypass: AzureServices is set

---

## Cost Optimization Next Steps

Once you have cost data:

1. **Week 1**: Run Get-AzureInventory-Enhanced.ps1 (identifies 437 opportunities)
2. **Week 2-4**: Implement QUICK-ACTIONS.md ($6K-10K/month quick wins)
3. **Month 2+**: Strategic optimization ($5K-10K/month additional)

**Potential Savings**: $15,000-25,000/month ($180K-300K/year)

---

## Full Documentation

- **Complete Guide**: [FINOPS-DEPLOYMENT-PLAN.md](FINOPS-DEPLOYMENT-PLAN.md)
- **Phase 3 Details**: [PHASE3-COMPLETE-20260203.md](PHASE3-COMPLETE-20260203.md)
- **Opportunities**: [I:\eva-foundation\14-az-finops\FINOPS-OPPORTUNITIES-20260203.md](I:\eva-foundation\14-az-finops\FINOPS-OPPORTUNITIES-20260203.md)
- **Quick Actions**: [I:\eva-foundation\14-az-finops\QUICK-ACTIONS.md](I:\eva-foundation\14-az-finops\QUICK-ACTIONS.md)

---

**Status**: Ready to execute  
**Time to first data**: 24 hours (tomorrow at midnight UTC)  
**Total setup time**: 10 minutes  
**Expected impact**: $180K-300K/year cost optimization
