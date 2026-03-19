# 2-Week Shutdown Plan for marco* Resources in EsDAICoE-Sandbox

**Period**: March 3-17, 2026 (2 weeks)  
**Goal**: Minimize costs while preserving data and easy restart capability  
**Subscription**: EsDAICoE-Sandbox (d2d4e571-e0f2-4f6c-901a-f88f7669bcba)  
**Resource Group**: EsDAICoE-Sandbox

---

## 💰 Expected Savings: ~$200-280 (70-80% of monthly cost)

### Current Monthly Cost: ~$341-391
### 2-Week Cost with Shutdown: ~$65-110
### **Savings: ~$200-280** ✅

---

## 🎯 Shutdown Strategy Overview

| Action | Resources | Savings | Data Loss Risk |
|---|---|---|---|
| **STOP** | Container Apps, App Services, Functions | ~$85-105 | ✅ None - all data preserved |
| **DEALLOCATE** | VMs (if any) | N/A | ✅ None - disks preserved |
| **KEEP RUNNING** | Storage, Cosmos DB, Key Vault, ACR | ~$65-110/2wk | ✅ Data preserved |
| **PAUSE** | APIM Developer tier | N/A | ✅ Config preserved |

**Key Principle**: Stop all compute, keep all storage. Data is 100% safe.

---

## 📋 Step-by-Step Shutdown Commands

### ✅ Step 1: Authenticate to Azure

```powershell
# Login to Azure
az login --use-device-code

# Set subscription to EsDAICoE-Sandbox
az account set --subscription "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"

# Verify
az account show --output table
```

---

### 🛑 Step 2: Stop Container Apps (Save ~$55-75/month → ~$25-35 for 2 weeks)

Container Apps can scale to 0 replicas. They'll restart instantly when needed.

```powershell
$rg = "EsDAICoE-Sandbox"

# Stop all Container Apps by scaling to 0 replicas
Write-Host "Stopping Container Apps..." -ForegroundColor Yellow

az containerapp update `
  --name marco-eva-brain-api `
  --resource-group $rg `
  --min-replicas 0 `
  --max-replicas 0

az containerapp update `
  --name marco-eva-data-model `
  --resource-group $rg `
  --min-replicas 0 `
  --max-replicas 0

az containerapp update `
  --name marco-eva-faces `
  --resource-group $rg `
  --min-replicas 0 `
  --max-replicas 0

az containerapp update `
  --name marco-eva-roles-api `
  --resource-group $rg `
  --min-replicas 0 `
  --max-replicas 0

Write-Host "✓ All Container Apps stopped (scaled to 0)" -ForegroundColor Green
```

**Verify:**
```powershell
# Check all Container Apps are at 0 replicas
az containerapp list --resource-group $rg `
  --query "[].{Name:name, MinReplicas:properties.template.scale.minReplicas, MaxReplicas:properties.template.scale.maxReplicas}" `
  --output table
```

---

### 🛑 Step 3: Stop App Services & Functions (Save ~$48/month → ~$22 for 2 weeks)

```powershell
Write-Host "Stopping App Services and Functions..." -ForegroundColor Yellow

# Stop backend app
az webapp stop `
  --name marco-sandbox-backend `
  --resource-group $rg

# Stop enrichment app
az webapp stop `
  --name marco-sandbox-enrichment `
  --resource-group $rg

# Stop function app
az functionapp stop `
  --name marco-sandbox-func `
  --resource-group $rg

Write-Host "✓ All App Services and Functions stopped" -ForegroundColor Green
```

**Verify:**
```powershell
# Check all webapps are stopped
az webapp list --resource-group $rg `
  --query "[?starts_with(name, 'marco')].{Name:name, State:state}" `
  --output table

az functionapp list --resource-group $rg `
  --query "[?starts_with(name, 'marco')].{Name:name, State:state}" `
  --output table
```

---

### ⚠️ Step 4: API Management (Developer Tier - Cannot Stop, Consider Deletion)

**Option A: Keep Running** (Cost: ~$56/month = ~$26 for 2 weeks)
- ✅ Fastest restart (instant)
- ✅ All APIs and config preserved
- ❌ Costs $26 for 2 weeks of non-use

**Option B: Delete and Recreate Later** (Save $26)
- ✅ Zero cost during shutdown
- ❌ Must reconfigure APIs when restarting
- ❌ Lose custom domain bindings

```powershell
# OPTIONAL: Delete APIM to save $26 (ONLY if you can recreate config easily)
# CAUTION: This deletes all API configurations!

# Export APIM configuration first (backup)
az apim api list `
  --resource-group $rg `
  --service-name marco-sandbox-apim `
  --output json > "C:\eva-foundry\temp\apim-apis-backup-$(Get-Date -Format 'yyyyMMdd').json"

# Delete APIM (OPTIONAL - only if comfortable recreating)
# az apim delete --name marco-sandbox-apim --resource-group $rg --yes

Write-Host "⚠ API Management left running (Developer tier cannot be paused)" -ForegroundColor DarkYellow
Write-Host "  Cost during shutdown: ~$26 for 2 weeks" -ForegroundColor Gray
```

**Recommendation**: **Keep APIM running** unless you're comfortable recreating API configs.

---

### ⏸️ Step 5: Azure AI Search (Basic Tier - Cannot Stop, Consider Deletion)

**Option A: Keep Running** (Cost: ~$89/month = ~$41 for 2 weeks)
- ✅ All indexes and data preserved
- ✅ Instant restart
- ❌ Costs $41 for 2 weeks

**Option B: Delete and Recreate Later** (Save $41)
- ✅ Zero cost
- ❌ Must reindex all data (could take hours/days depending on corpus size)

```powershell
# OPTIONAL: Delete Search to save $41 (ONLY if you can rebuild indexes)
# CAUTION: This deletes all search indexes and data!

# Export search service configuration (backup)
$searchName = "marco-sandbox-search"

# List indexes (for reference)
az search index list `
  --resource-group $rg `
  --service-name $searchName `
  --query "[].{name:name, documentCount:statistics.documentCount}" `
  --output json > "C:\eva-foundry\temp\search-indexes-backup-$(Get-Date -Format 'yyyyMMdd').json"

# Delete Search service (OPTIONAL - only if comfortable rebuilding)
# az search service delete --name $searchName --resource-group $rg --yes

Write-Host "⚠ Azure AI Search left running (Basic tier cannot be paused)" -ForegroundColor DarkYellow
Write-Host "  Cost during shutdown: ~$41 for 2 weeks" -ForegroundColor Gray
```

**Recommendation**: **Keep Search running** unless you have automated reindexing scripts.

---

### ✅ Step 6: Keep These Running (Already Cost-Optimized)

These services have **zero or minimal cost when idle**:

```powershell
Write-Host "`n✓ Keeping these resources running (minimal/zero cost when idle):" -ForegroundColor Green
Write-Host "  • Cosmos DB (Serverless) - Only pays for operations (~$0 when idle)" -ForegroundColor Gray
Write-Host "  • Storage Accounts (2) - Only pays for storage (~$5/month, minimal)" -ForegroundColor Gray
Write-Host "  • Container Registry - Fixed $6.50/month, needed for restart" -ForegroundColor Gray
Write-Host "  • Key Vault - Fixed $1/month, stores secrets safely" -ForegroundColor Gray
Write-Host "  • Azure OpenAI (2) - Pay-per-call only (~$0 when idle)" -ForegroundColor Gray
Write-Host "  • Cognitive Services - Pay-per-transaction only (~$0 when idle)" -ForegroundColor Gray
Write-Host "  • Document Intelligence - Pay-per-page only (~$0 when idle)" -ForegroundColor Gray
Write-Host "  • Application Insights - Pay-per-GB only (~$0 when idle)" -ForegroundColor Gray
Write-Host "  • Log Analytics - Pay-per-GB only (~$0 when idle)" -ForegroundColor Gray
Write-Host "  • Event Hubs Namespace - Fixed $11/month, keep for config" -ForegroundColor Gray
Write-Host "  • Data Factory - Pay-per-run only (~$0 when idle)" -ForegroundColor Gray
```

**Total cost of "keep running" resources: ~$65-110 for 2 weeks**

---

## 📊 Cost Breakdown During Shutdown

| Resource Category | Normal Monthly | 2-Week Shutdown | Savings |
|---|---|---|---|
| **Compute (Container Apps)** | $55-75 | $0 | ✅ $25-35 |
| **Compute (App Services)** | $48 | $0 | ✅ $22 |
| **APIM** | $56 | $26 | ⚠️ $26 if kept |
| **AI Search** | $89 | $41 | ⚠️ $41 if kept |
| **Storage & Data** | $25-35 | $12-17 | N/A |
| **Pay-per-use (idle)** | $20-40 | ~$0 | ✅ $10-20 |
| **Fixed (minimal)** | $18 | $9 | N/A |
| **TOTAL** | **$341-391** | **$65-110** | **$200-280** |

**If you also delete APIM + Search**: Total cost drops to **~$24-43** (savings: **~$250-317**)

---

## 🔄 Restart Commands (After 2 Weeks)

### Step 1: Restart Container Apps

```powershell
$rg = "EsDAICoE-Sandbox"

Write-Host "Restarting Container Apps..." -ForegroundColor Yellow

# Restore scale settings (1-3 replicas)
az containerapp update `
  --name marco-eva-brain-api `
  --resource-group $rg `
  --min-replicas 1 `
  --max-replicas 1

az containerapp update `
  --name marco-eva-data-model `
  --resource-group $rg `
  --min-replicas 1 `
  --max-replicas 1

az containerapp update `
  --name marco-eva-faces `
  --resource-group $rg `
  --min-replicas 1 `
  --max-replicas 3

az containerapp update `
  --name marco-eva-roles-api `
  --resource-group $rg `
  --min-replicas 1 `
  --max-replicas 3

Write-Host "✓ Container Apps restarted" -ForegroundColor Green
```

### Step 2: Restart App Services & Functions

```powershell
Write-Host "Restarting App Services and Functions..." -ForegroundColor Yellow

az webapp start --name marco-sandbox-backend --resource-group $rg
az webapp start --name marco-sandbox-enrichment --resource-group $rg
az functionapp start --name marco-sandbox-func --resource-group $rg

Write-Host "✓ All App Services and Functions restarted" -ForegroundColor Green
```

### Step 3: Verify All Services are Running

```powershell
# Check Container Apps
az containerapp list --resource-group $rg `
  --query "[?starts_with(name, 'marco')].{Name:name, Status:properties.runningStatus, Replicas:properties.template.scale.minReplicas}" `
  --output table

# Check App Services
az webapp list --resource-group $rg `
  --query "[?starts_with(name, 'marco')].{Name:name, State:state}" `
  --output table

# Check Functions
az functionapp list --resource-group $rg `
  --query "[?starts_with(name, 'marco')].{Name:name, State:state}" `
  --output table

# Test Container App endpoints
Write-Host "`nTesting Container App endpoints..." -ForegroundColor Yellow
$apps = @(
    "https://marco-eva-brain-api.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io/health",
    "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io/health",
    "https://marco-eva-faces.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io/health",
    "https://marco-eva-roles-api.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io/health"
)

foreach ($url in $apps) {
    try {
        $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 10 -ErrorAction Stop
        Write-Host "  ✓ $(($url -split '//')[1].Split('.')[0]) - HTTP $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠ $(($url -split '//')[1].Split('.')[0]) - Not responding yet (may need 30-60 sec)" -ForegroundColor DarkYellow
    }
}
```

**Expected restart time**: 30-60 seconds for Container Apps, instant for App Services.

---

## 📝 Quick Reference Commands

### Single Command Shutdown

```powershell
# Copy-paste this entire block for quick shutdown
$rg = "EsDAICoE-Sandbox"

# Container Apps to 0
@('marco-eva-brain-api', 'marco-eva-data-model', 'marco-eva-faces', 'marco-eva-roles-api') | ForEach-Object {
    az containerapp update --name $_ --resource-group $rg --min-replicas 0 --max-replicas 0
}

# Stop App Services
@('marco-sandbox-backend', 'marco-sandbox-enrichment') | ForEach-Object {
    az webapp stop --name $_ --resource-group $rg
}

# Stop Functions
az functionapp stop --name marco-sandbox-func --resource-group $rg

Write-Host "`n✓ Shutdown complete! Compute resources stopped." -ForegroundColor Green
Write-Host "  Expected cost for 2 weeks: ~$65-110 (vs. $160-185 if left running)" -ForegroundColor Cyan
```

### Single Command Restart

```powershell
# Copy-paste this entire block for quick restart
$rg = "EsDAICoE-Sandbox"

# Container Apps back to normal scale
az containerapp update --name marco-eva-brain-api --resource-group $rg --min-replicas 1 --max-replicas 1
az containerapp update --name marco-eva-data-model --resource-group $rg --min-replicas 1 --max-replicas 1
az containerapp update --name marco-eva-faces --resource-group $rg --min-replicas 1 --max-replicas 3
az containerapp update --name marco-eva-roles-api --resource-group $rg --min-replicas 1 --max-replicas 3

# Start App Services
@('marco-sandbox-backend', 'marco-sandbox-enrichment') | ForEach-Object {
    az webapp start --name $_ --resource-group $rg
}

# Start Functions
az functionapp start --name marco-sandbox-func --resource-group $rg

Write-Host "`n✓ Restart complete! All services running." -ForegroundColor Green
```

---

## ⚠️ Important Notes

### Data Safety
- ✅ **All data is preserved**: Cosmos DB, Storage, Container images, Key Vault secrets
- ✅ **All configurations preserved**: App settings, environment variables, ingress rules
- ✅ **No data loss**: This is a compute shutdown only

### Cold Start Time
- Container Apps: 30-60 seconds first request
- App Services: Instant (already allocated)
- Functions: 1-5 seconds first invocation

### What WON'T Work During Shutdown
- ❌ Any API calls to Container Apps (503 Service Unavailable)
- ❌ Web app endpoints (stopped)
- ❌ Function triggers (stopped)
- ✅ Data queries to Cosmos DB still work (if accessing directly)
- ✅ Storage account access still works
- ✅ Key Vault secrets retrieval still works

### Monitoring During Shutdown
- Application Insights will show $0 ingestion (no telemetry)
- Cost Management will show reduced compute charges
- Resource health will show "Stopped" or "Deallocated"

---

## 💡 Alternative: Delete and Recreate from Bicep

If you want **maximum savings** (~$0 cost for 2 weeks), you can delete all resources and redeploy from your Bicep templates when needed.

### Delete Everything (Save ~$160-185)
```powershell
# CAUTION: This deletes all resources! Only if you have Bicep templates ready.
az group delete --name EsDAICoE-Sandbox --yes --no-wait
```

### Recreate When Needed
```powershell
# Deploy from your new marcosub templates
cd C:\eva-foundry\22-rg-sandbox\bicep-templates
.\DEPLOY-MARCOSUB.ps1 -SubscriptionId "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
```

**Trade-off**: Must repopulate Cosmos DB data, push container images, reconfigure all settings.

---

## 🎯 Recommended Action Plan

### Day 1 (Today - March 3)
1. Run the "Single Command Shutdown" script above
2. Verify all Container Apps scaled to 0
3. Verify all App Services/Functions stopped
4. Check Azure Cost Management in 24 hours to see reduced charges

### Day 14 (March 17 - Return to Work)
1. Run the "Single Command Restart" script
2. Wait 30-60 seconds for Container Apps to warm up
3. Test endpoints
4. Resume normal work

### Expected Outcome
- **Savings**: ~$200-280 for 2 weeks (~70-80% reduction)
- **Effort**: 5 minutes to shutdown, 5 minutes to restart
- **Risk**: Zero data loss

---

## 📞 Support

If anything goes wrong during restart:
1. Check Container App logs: `az containerapp logs show --name <app-name> --resource-group $rg --follow`
2. Check App Service logs: `az webapp log tail --name <app-name> --resource-group $rg`
3. Verify network connectivity (VNet rules, NSG, etc.)
4. Check application settings (may need to reset environment variables)

---

**Ready to shutdown?** Run the "Single Command Shutdown" block above! ⬆️
