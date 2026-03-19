# Cost Analysis: Fixed vs. Variable Costs - marcosub Deployment

**Analysis Date**: March 3, 2026  
**Environment**: Dev (parameters.dev.json)  
**Total Monthly Cost**: $341-391 CAD

---

## 💵 Fixed Costs (Billed Monthly Regardless of Usage)

### 🔴 HIGH FIXED COST - Prime Candidates for Scaling Down

| Resource | Current SKU | Monthly Cost | Can Scale Down To | Savings | Impact |
|---|---|---|---|---|---|
| **API Management** | Developer | **$56/month** | Consumption tier | **~$56/month** | Dev-only feature loss (portal customization) |
| **Azure AI Search** | Basic | **$89/month** | Free tier | **~$89/month** | 50MB limit, 3 indexes max, 10K docs |
| **App Service Plans (3)** | B1 × 3 | **$48/month** | F1 Free × 3 | **~$48/month** | 60 min/day CPU limit, 1GB RAM |

**Potential Fixed Cost Savings: $145-193/month (42-49% reduction)**

### 🟡 MEDIUM FIXED COST - Consider for Non-Production

| Resource | Current SKU | Monthly Cost | Can Scale Down To | Savings | Impact |
|---|---|---|---|---|---|
| **Container Apps (4)** | 0.5 CPU, 1Gi RAM | ~$55-75/month | 0.25 CPU, 0.5Gi RAM | ~$30/month | Slower response times |
| **Event Hubs Namespace** | Standard | $11/month | Basic | $11.50/month | No Kafka, no auto-inflate |
| **Container Registry** | Basic | $6.50/month | None (use Docker Hub) | $6.50/month | Public images only |

**Additional Savings: $36-48/month**

### 🟢 LOW FIXED COST - Keep As-Is

| Resource | Current SKU | Monthly Cost | Notes |
|---|---|---|---|
| **Key Vault** | Standard | $1/month | Cannot reduce; operations are $0.03/10K |
| **Storage Accounts (2)** | Standard LRS | ~$5/month | Already minimal; data transfer costs extra |

---

## 📊 Consumption-Based Costs (Pay Per Use)

### These Scale Automatically to Zero When Idle

| Resource | Pricing Model | Monthly Cost (Dev) | Notes |
|---|---|---|---|
| **Cosmos DB** | Serverless RU/s | $10-30 | Only pay for operations; idle = $0 |
| **Azure OpenAI (2)** | Per-token | Variable | Pay per API call; idle = $0 |
| **Cognitive Services** | Per-transaction | Variable | Pay per API call; idle = $0 |
| **Document Intelligence** | Per-page | Variable | Pay per document processed |
| **Application Insights** | Per-GB ingested | $5-15 | ~$0.25/GB; 5GB free/month |
| **Log Analytics** | Per-GB ingested | $5-10 | ~$3/GB; retention costs extra |
| **Data Factory** | Per-run | Minimal | Pay per pipeline execution |

**These resources have NO fixed cost when idle - perfect for dev environments!**

---

## 🎯 Recommended Cost Optimization Strategies

### Strategy 1: Minimal Dev Environment ($100-150/month)
**For occasional testing and development.**

```json
{
  "apimSku": "Consumption",           // Save $56/month
  "searchSku": "free",                // Save $89/month
  "backendPlanSku": "F1",             // Save $48/month (3 plans)
  "containerAppCpu": "0.25",          // Save $30/month
  "containerAppMemory": "0.5Gi"
}
```

**Limitations:**
- ❌ APIM Developer Portal features
- ❌ AI Search limited to 50MB, 10K docs
- ❌ App Services: 60 min CPU/day, cold starts
- ⚠️ Slower Container App responses

**Best For:** Prototyping, infrequent testing, cost-sensitive dev work

---

### Strategy 2: Balanced Dev Environment ($200-250/month) ⭐ RECOMMENDED
**Good performance with reasonable costs.**

```json
{
  "apimSku": "Consumption",           // Save $56/month
  "searchSku": "basic",               // Keep for testing
  "backendPlanSku": "B1",             // Keep for reliability
  "containerAppCpu": "0.25",          // Save $30/month
  "containerAppMemory": "0.5Gi"
}
```

**Trade-offs:**
- ✅ Keep AI Search Basic (realistic testing)
- ✅ Keep App Service B1 (no time limits)
- ✅ APIM Consumption (auto-scales, good for dev)
- ⚠️ Container Apps: slightly slower responses

**Best For:** Active development with realistic testing

---

### Strategy 3: Current Configuration ($341-391/month)
**Full-featured development environment.**

**Pros:**
- ✅ No performance compromises
- ✅ APIM Developer Portal (good for API testing)
- ✅ Full Container App performance
- ✅ All features available

**Best For:** Production-like testing, demos, team collaboration

---

## 🔧 Scale-Down Implementation

### Option A: Update Parameters File

Edit [parameters.dev.json](c:\eva-foundry\22-rg-sandbox\bicep-templates\parameters.dev.json):

```json
{
  "parameters": {
    // Change these values:
    "apimSku": {
      "value": "Consumption"        // was "Developer"
    },
    "searchSku": {
      "value": "free"               // was "basic" 
    },
    "backendPlanSku": {
      "value": "F1"                 // was "B1"
    },
    "containerAppCpu": {
      "value": "0.25"               // was "0.5"
    },
    "containerAppMemory": {
      "value": "0.5Gi"              // was "1Gi"
    }
  }
}
```

Then redeploy:
```powershell
.\DEPLOY-MARCOSUB.ps1 -SubscriptionId "YOUR_ID"
```

### Option B: Scale Down After Deployment

```powershell
$rg = "EVA-Sandbox-dev"

# Scale down Container Apps to 0.25 CPU, 0.5Gi RAM
az containerapp update --name marco-eva-brain-api --resource-group $rg `
  --cpu 0.25 --memory 0.5Gi

az containerapp update --name marco-eva-data-model --resource-group $rg `
  --cpu 0.25 --memory 0.5Gi

az containerapp update --name marco-eva-faces --resource-group $rg `
  --cpu 0.25 --memory 0.5Gi

az containerapp update --name marco-eva-roles-api --resource-group $rg `
  --cpu 0.25 --memory 0.5Gi

# Scale down App Service Plans to F1 (Free)
az appservice plan update --name marco-sandbox-asp-backend --resource-group $rg --sku F1
az appservice plan update --name marco-sandbox-asp-enrichment --resource-group $rg --sku F1
az appservice plan update --name marco-sandbox-asp-func --resource-group $rg --sku F1

# Note: APIM and Search SKU changes require resource recreation
```

### Option C: Start/Stop Resources When Not in Use

**Best for occasional development (evenings/weekends):**

```powershell
# Stop all App Services (saves compute costs)
az webapp stop --name marco-sandbox-backend --resource-group $rg
az webapp stop --name marco-sandbox-enrichment --resource-group $rg
az functionapp stop --name marco-sandbox-func --resource-group $rg

# Scale Container Apps to 0 replicas (saves compute costs)
az containerapp update --name marco-eva-brain-api --resource-group $rg --min-replicas 0
az containerapp update --name marco-eva-data-model --resource-group $rg --min-replicas 0
az containerapp update --name marco-eva-faces --resource-group $rg --min-replicas 0
az containerapp update --name marco-eva-roles-api --resource-group $rg --min-replicas 0

# Start when needed
az webapp start --name marco-sandbox-backend --resource-group $rg
# ... etc
```

**Savings:** ~70% during stopped periods  
**Trade-off:** Cold start time (~30-60 seconds)

---

## 📊 Cost Comparison Summary

| Strategy | Monthly Cost | vs. Current | Best For |
|---|---|---|---|
| **Minimal Dev** | $100-150 | -$191-241 (58-70% less) | Prototyping, infrequent use |
| **Balanced Dev** ⭐ | $200-250 | -$91-141 (27-41% less) | Active development |
| **Current Config** | $341-391 | Baseline | Production-like testing |
| **Start/Stop** | $100-120 (30% uptime) | -$241-271 (70% less) | Occasional weekend work |

---

## 🚦 Resource-by-Resource Scaling Guide

### Cannot Scale Down (Fixed Architecture)
- ❌ **Key Vault** - Already minimal ($1/month)
- ❌ **Storage Accounts** - Already Standard LRS (cheapest durable option)
- ❌ **Event Grid System Topics** - Auto-created, no cost
- ❌ **Log Analytics Workspace** - Pay-per-GB, no fixed tier

### Can Scale Down with Minimal Impact
- ✅ **APIM**: Developer → Consumption (**save $56/month**)
- ✅ **Container Apps**: 0.5→0.25 CPU (**save $30/month**)
- ✅ **Container Registry**: Keep Basic or use Docker Hub (**save $6.50/month**)

### Can Scale Down with Moderate Impact
- ⚠️ **AI Search**: Basic → Free (**save $89/month**, 50MB limit)
- ⚠️ **App Service Plans**: B1 → F1 (**save $48/month**, 60min/day limit)

### Should NOT Scale Down
- 🛑 **Cosmos DB** - Already serverless (pay-per-use)
- 🛑 **Azure OpenAI** - Already pay-per-call
- 🛑 **Cognitive Services** - Already pay-per-transaction
- 🛑 **Application Insights** - Already pay-per-GB

---

## 💡 Recommendations

### For Your marcosub Clean Slate Deployment:

1. **Start with Balanced Strategy** ($200-250/month)
   - APIM Consumption tier
   - AI Search Basic (for realistic testing)
   - Container Apps at 0.25 CPU
   - App Service Plans B1 (no time limits)

2. **Monitor Usage for 2 Weeks**
   - Check Container App CPU/memory utilization
   - Verify App Service compute time
   - Review AI Search index size and query count

3. **Further Optimize Based on Actual Usage**
   - If AI Search <50MB and <10K docs → switch to Free
   - If App Services <60min/day → switch to F1
   - If weekend-only dev → implement start/stop automation

4. **Set Cost Alerts**
   ```powershell
   az consumption budget create `
     --budget-name "EVA-Dev-Monthly-Limit" `
     --amount 300 `
     --resource-group EVA-Sandbox-dev `
     --time-grain Monthly `
     --start-date $(Get-Date -Format 'yyyy-MM-01')
   ```

---

## 🎯 Quick Win: Deploy with Balanced Config

Update `parameters.dev.json` before deployment:

```powershell
cd C:\eva-foundry\22-rg-sandbox\bicep-templates

# Edit parameters.dev.json - change these 3 values:
# apimSku: "Consumption"
# containerAppCpu: "0.25"
# containerAppMemory: "0.5Gi"

# Deploy
.\DEPLOY-MARCOSUB.ps1 -SubscriptionId "YOUR_ID"

# Expected monthly cost: $200-250 (vs. $341-391)
# Savings: ~$100-150/month (30-40% reduction)
```

**This gives you the best balance of cost savings and performance for active development work.**
