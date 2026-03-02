# EsDAICoE-Sandbox Deployment Guide

**Target**: EsDAICoE-Sandbox Resource Group (Canada Central)  
**Status**: Ready to deploy (Owner role active)  
**Method**: Azure CLI (no Terraform)  
**Budget**: $100-150 CAD/month  
**Timeline**: 2-4 hours for initial deployment

---

## Quick Start (5 Minutes)

```powershell
# 1. Navigate to project folder
cd I:\eva-foundation\22-rg-sandbox

# 2. Preview deployment (validate permissions and naming)
.\Deploy-Sandbox-AzCLI.ps1 -WhatIf

# 3. Execute deployment (creates 12 resources)
.\Deploy-Sandbox-AzCLI.ps1
```

---

## Pre-Flight Checklist

### Your Permissions ✅
- [x] Owner role on EsDAICoE-Sandbox (active until April 17, 2026)
- [x] Reader on EsDAICoESub subscription
- [x] Cost Management Contributor (for budget alerts)

### Azure CLI Setup ✅
```powershell
# Verify Azure CLI installed
az version

# Check authentication
az account show --query "{Account:user.name, Tenant:tenantId}" -o table

# Should show:
# Account: marco.presta@hrsdc-rhdcc.gc.ca
# Tenant: bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8

# If not authenticated, login:
az login --use-device-code --tenant bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8
```

### Resource Group Validation ✅
```powershell
# Verify EsDAICoE-Sandbox exists
az group show --name "EsDAICoE-Sandbox" --query "{Name:name, Location:location, State:properties.provisioningState}"

# Expected output:
# Name: EsDAICoE-Sandbox
# Location: canadacentral
# State: Succeeded
```

---

## Resources to Deploy (12 Total)

| # | Resource | SKU/Tier | Purpose | Monthly Cost |
|---|----------|----------|---------|--------------|
| 1 | Azure Cognitive Search | Basic | Hybrid vector+keyword search | $75 |
| 2 | Cosmos DB Account | Serverless | Session logs, metadata | $5-10 |
| 3 | Storage Account | Standard_LRS | Document blob storage | $5 |
| 4 | Web App (Backend) | B1 | Python/Quart API server | $13 |
| 5 | Web App (Enrichment) | B1 | Embedding generation | $13 |
| 6 | Function App | Consumption | Document pipeline | $1-5 |
| 7-9 | App Service Plans (x3) | B1 + Y1 | Host Web Apps + Functions | Included |
| 10 | Key Vault | Standard | Secrets management | $0.03 |
| 11 | Container Registry | Basic | Docker images | $5 |
| 12 | Application Insights | Standard | Telemetry | $5 |
| **TOTAL** | | | | **~$122-131/month** |

**Reused Resources** (NO additional cost):
- Azure OpenAI: infoasst-aoai-dev2 (gpt-4o, embeddings)
- Document Intelligence: infoasst-docint-dev2
- APIM: TBD (pending policy decision)

---

## Deployment Steps

### Step 1: Preview Deployment (2 minutes)

```powershell
cd I:\eva-foundation\22-rg-sandbox
.\Deploy-Sandbox-AzCLI.ps1 -WhatIf
```

**Expected Output**:
```
[PASS] Azure CLI 2.xx.x
[PASS] Subscription: EsDAICoESub
[PASS] Resource group: EsDAICoE-Sandbox
[PASS] You have Owner role

Resources to deploy:
  - acr: marcosandboxacr20260203
  - appinsights: marco-sandbox-appinsights
  - asp_backend: marco-sandbox-asp-backend
  - asp_enrichment: marco-sandbox-asp-enrichment
  - asp_function: marco-sandbox-asp-func
  - cosmosdb: marco-sandbox-cosmos
  - function: marco-sandbox-func
  - keyvault: marco-sandbox-kv-20260203
  - search: marco-sandbox-search
  - storage: marcosandboxstore20260203
  - webapp_backend: marco-sandbox-backend
  - webapp_enrichment: marco-sandbox-enrichment

[WHATIF MODE] Deployment plan preview complete
```

### Step 2: Execute Deployment (15-30 minutes)

```powershell
.\Deploy-Sandbox-AzCLI.ps1
```

**What Happens**:
1. Pre-flight validation (authentication, permissions, RG exists)
2. Resource naming with timestamp uniqueness
3. Sequential deployment of 12 resources
4. Progress tracking with duration per resource
5. Deployment log saved as JSON

**Expected Timeline**:
- Storage Account: ~30 seconds
- Key Vault: ~30 seconds
- Container Registry: ~1 minute
- Cognitive Search: ~2 minutes
- Cosmos DB: ~3 minutes
- Application Insights: ~30 seconds
- App Service Plans (x3): ~3 minutes total
- Web Apps (x2): ~2 minutes total
- Function App: ~2 minutes
- **Total**: 15-20 minutes

### Step 3: Validate Deployment

```powershell
# List all resources in sandbox
az resource list --resource-group "EsDAICoE-Sandbox" --query "[].{Name:name, Type:type, Location:location}" -o table

# Count resources (should be 12+)
az resource list --resource-group "EsDAICoE-Sandbox" --query "length([])"

# Check deployment log
Get-Content .\deployment-log-*.json | ConvertFrom-Json | Format-Table
```

---

## Post-Deployment Configuration

### 1. Configure Azure OpenAI Connection

**Option A: Use Existing Dev2 Instance** (Recommended)
```powershell
# Get connection details
az cognitiveservices account show --name "infoasst-aoai-dev2" --resource-group "infoasst-dev2" --query "{Endpoint:properties.endpoint, Location:location}"

# Get API key (if needed)
az cognitiveservices account keys list --name "infoasst-aoai-dev2" --resource-group "infoasst-dev2" --query "key1" -o tsv

# Add to backend environment variables:
# AZURE_OPENAI_ENDPOINT=https://infoasst-aoai-dev2.openai.azure.com
# AZURE_OPENAI_CHAT_DEPLOYMENT=gpt-4o
# AZURE_OPENAI_EMBEDDING_DEPLOYMENT=dev2-text-embedding
```

**Option B: Deploy New Instance** (If dev2 reuse not approved)
```powershell
az cognitiveservices account create \
  --name "marco-sandbox-openai" \
  --resource-group "EsDAICoE-Sandbox" \
  --location "canadaeast" \
  --kind OpenAI \
  --sku S0 \
  --custom-domain "marco-sandbox-openai"

# Deploy models (gpt-4o + embeddings)
# Cost: ~$200-300/month
```

### 2. Create Search Index

```powershell
# Get Search service details
$searchEndpoint = az search service show --name "marco-sandbox-search" --resource-group "EsDAICoE-Sandbox" --query "hostName" -o tsv

# Get admin key
$searchKey = az search admin-key show --service-name "marco-sandbox-search" --resource-group "EsDAICoE-Sandbox" --query "primaryKey" -o tsv

# Create index using Azure portal or REST API
# Schema: Based on EVA-JP-v1.2\azure_search\create_vector_index.json
```

### 3. Deploy Application Code

```powershell
# Backend deployment
cd I:\EVA-JP-v1.2\app\backend
az webapp deployment source config-zip \
  --name "marco-sandbox-backend" \
  --resource-group "EsDAICoE-Sandbox" \
  --src backend.zip

# Enrichment deployment
cd I:\EVA-JP-v1.2\app\enrichment
az webapp deployment source config-zip \
  --name "marco-sandbox-enrichment" \
  --resource-group "EsDAICoE-Sandbox" \
  --src enrichment.zip

# Function deployment
cd I:\EVA-JP-v1.2\functions
func azure functionapp publish marco-sandbox-func
```

### 4. Set Environment Variables

Create `backend.env` for backend Web App:
```bash
AZURE_OPENAI_ENDPOINT=https://infoasst-aoai-dev2.openai.azure.com
AZURE_OPENAI_CHAT_DEPLOYMENT=gpt-4o
AZURE_OPENAI_EMBEDDING_DEPLOYMENT=dev2-text-embedding
AZURE_SEARCH_ENDPOINT=https://marco-sandbox-search.search.windows.net
AZURE_SEARCH_INDEX=index-jurisprudence-sandbox
COSMOSDB_ENDPOINT=https://marco-sandbox-cosmos.documents.azure.com:443/
COSMOSDB_DATABASE_NAME=chatlogs
STORAGE_ACCOUNT_NAME=marcosandboxstore20260203
STORAGE_CONTAINER_NAME=documents
```

Apply to Web App:
```powershell
az webapp config appsettings set \
  --name "marco-sandbox-backend" \
  --resource-group "EsDAICoE-Sandbox" \
  --settings @backend.env
```

---

## Troubleshooting

### Deployment Failures

**Issue**: Resource name already exists (409 error)
```
Solution: Resource names must be globally unique
- Storage Account: Change suffix in script (line 30)
- Container Registry: Change suffix in script (line 31)
- Key Vault: Change suffix in script (line 32)
```

**Issue**: Insufficient permissions (403 error)
```
Solution: Verify Owner role is active
az role assignment list --assignee "marco.presta@hrsdc-rhdcc.gc.ca" --resource-group "EsDAICoE-Sandbox"

If not showing Owner, check PIM activation
```

**Issue**: Quota exceeded
```
Solution: Check subscription quotas
az vm list-usage --location "canadacentral" -o table

Contact infrastructure team for quota increase
```

### Retry Failed Resources

```powershell
# Re-run deployment script (idempotent)
.\Deploy-Sandbox-AzCLI.ps1

# Or deploy specific resource manually:
az search service create \
  --name "marco-sandbox-search" \
  --resource-group "EsDAICoE-Sandbox" \
  --location "canadacentral" \
  --sku basic
```

---

## Cost Monitoring

### Set Budget Alert

```powershell
# Create budget (requires Cost Management Contributor role)
az consumption budget create \
  --budget-name "marco-sandbox-budget" \
  --amount 150 \
  --time-grain Monthly \
  --start-date 2026-02-01 \
  --end-date 2026-04-30 \
  --resource-group "EsDAICoE-Sandbox" \
  --notification-enabled true \
  --notification-threshold 80 \
  --contact-emails "marco.presta@hrsdc-rhdcc.gc.ca"
```

### Monitor Current Costs

```powershell
# Get current month costs
az consumption usage list \
  --start-date 2026-02-01 \
  --end-date 2026-02-28 \
  --query "[?contains(instanceId, 'EsDAICoE-Sandbox')].{Service:meterName, Cost:pretaxCost}" \
  -o table

# Get cost forecast
# (Use Azure Portal > Cost Management > Cost Analysis)
```

---

## Cleanup (When Done Testing)

```powershell
# Delete all resources in sandbox (DESTRUCTIVE!)
az resource list --resource-group "EsDAICoE-Sandbox" --query "[].id" -o tsv | ForEach-Object {
    az resource delete --ids $_
}

# Or delete specific resources
az search service delete --name "marco-sandbox-search" --resource-group "EsDAICoE-Sandbox" --yes
az cosmosdb delete --name "marco-sandbox-cosmos" --resource-group "EsDAICoE-Sandbox" --yes
```

**Note**: Do NOT delete the resource group itself (EsDAICoE-Sandbox) - it's shared!

---

## Next Steps After Deployment

1. **Test RAG Pipeline**
   - Upload test document to blob storage
   - Verify Function pipeline processes it
   - Check Search index has documents
   - Test chat interface

2. **Configure Frontend** (Optional)
   ```powershell
   cd I:\EVA-JP-v1.2\app\frontend
   npm install
   npm run build
   # Deploy to Static Web App or blob storage with CDN
   ```

3. **Enable Monitoring**
   - Configure Application Insights
   - Set up alerts for errors/performance
   - Create dashboard in Azure portal

4. **Document Configuration**
   - Save connection strings to Key Vault
   - Update README with sandbox-specific details
   - Create runbook for common operations

---

## Support

**Questions or Issues?**
- Check deployment log: `deployment-log-*.json`
- Review Azure Portal resource health
- Consult copilot-instructions.md for patterns
- Contact: marco.presta@hrsdc-rhdcc.gc.ca

**Last Updated**: February 3, 2026
