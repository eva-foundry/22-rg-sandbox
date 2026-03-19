# Marco EVA Infrastructure - Clean Slate Deployment to marcosub

**Target**: marcosub subscription (clean slate dev environment)  
**Date**: March 3, 2026  
**Status**: Ready for deployment

## 🎯 Pre-Deployment Checklist

### 1. Subscription Details
- [ ] Subscription ID for marcosub: `_________________`
- [ ] Subscription Name: `_________________`
- [ ] Tenant ID: `9ed55846-8a81-4246-acd8-b1a01abfc0d1` (verify)
- [ ] User has Owner or Contributor + RBAC Admin role

### 2. Resource Group Configuration
- [ ] Resource Group Name: `EVA-Sandbox-dev` (recommended)
- [ ] Primary Location: `canadacentral` (default)
- [ ] Secondary Location: `canadaeast` (for AI services)

### 3. Naming Convention
Current parameters use `marco` prefix. Verify if you want:
- **Keep**: `marco-eva-brain-api`, `marco-sandbox-cosmos`, etc.
- **Change**: Update `resourcePrefix` in `parameters.dev.json`

### 4. Required Permissions
Ensure you have:
- [ ] `Microsoft.App/managedEnvironments` resource provider registered
- [ ] `Microsoft.DocumentDB` resource provider registered
- [ ] `Microsoft.CognitiveServices` resource provider registered
- [ ] `Microsoft.ContainerRegistry` resource provider registered
- [ ] `Microsoft.KeyVault` resource provider registered

## 🚀 Deployment Steps

### Step 1: Authenticate and Set Subscription
```powershell
# Login (if not already done)
az login --use-device-code

# List subscriptions to find marcosub
az account list --output table

# Set the target subscription
az account set --subscription "MARCOSUB_SUBSCRIPTION_ID"

# Verify
az account show --output table
```

### Step 2: Register Required Resource Providers
```powershell
# Register all required providers
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

foreach ($provider in $providers) {
    Write-Host "Registering $provider..." -ForegroundColor Yellow
    az provider register --namespace $provider --wait
}

Write-Host "`n[OK] All providers registered" -ForegroundColor Green
```

### Step 3: Validate Template
```powershell
cd C:\eva-foundry\22-rg-sandbox\bicep-templates

# Create resource group
az group create `
  --name EVA-Sandbox-dev `
  --location canadacentral

# Validate template before deployment
az deployment group validate `
  --resource-group EVA-Sandbox-dev `
  --template-file main.bicep `
  --parameters parameters.dev.json

# Check what-if (preview changes)
az deployment group what-if `
  --resource-group EVA-Sandbox-dev `
  --template-file main.bicep `
  --parameters parameters.dev.json
```

### Step 4: Deploy Infrastructure (Automated)
```powershell
# Option A: Automated deployment with RBAC configuration
.\Deploy-Infrastructure.ps1 `
  -Environment dev `
  -SubscriptionId "MARCOSUB_SUBSCRIPTION_ID" `
  -ResourceGroupName "EVA-Sandbox-dev" `
  -Location canadacentral

# Option B: Manual deployment
az deployment group create `
  --resource-group EVA-Sandbox-dev `
  --template-file main.bicep `
  --parameters parameters.dev.json `
  --name "eva-deployment-$(Get-Date -Format 'yyyyMMdd-HHmm')"
```

### Step 5: Post-Deployment Configuration

#### 5.1 Push Container Images to New ACR
```powershell
# Get new ACR login server
$acrName = "marcoacr$(Get-Date -Format 'yyyyMMdd')"
$newAcr = az acr show --name $acrName --query loginServer -o tsv

# Login to source ACR (old environment)
az acr login --name marcosandacr20260203

# Login to new ACR
az acr login --name $acrName

# Pull and push images
$images = @(
    @{name='eva-brain-api'; tag='sprint7-epic-scope'},
    @{name='eva-data-model-api'; tag='20260302-1300'},
    @{name='eva-faces'; tag='20260226-v16'},
    @{name='eva-roles-api'; tag='latest'}
)

foreach ($img in $images) {
    Write-Host "Migrating $($img.name):$($img.tag)..." -ForegroundColor Yellow
    
    # Pull from old ACR
    docker pull marcosandacr20260203.azurecr.io/$($img.name):$($img.tag)
    
    # Tag for new ACR
    docker tag `
        marcosandacr20260203.azurecr.io/$($img.name):$($img.tag) `
        $newAcr/$($img.name):$($img.tag)
    
    # Push to new ACR
    docker push $newAcr/$($img.name):$($img.tag)
}

Write-Host "`n[OK] All images migrated to new ACR" -ForegroundColor Green
```

#### 5.2 Configure Cosmos DB
```powershell
# Get Cosmos DB account name
$cosmosAccount = "marco-sandbox-cosmos"

# Create databases
az cosmosdb sql database create `
  --account-name $cosmosAccount `
  --resource-group EVA-Sandbox-dev `
  --name eva-foundation

az cosmosdb sql database create `
  --account-name $cosmosAccount `
  --resource-group EVA-Sandbox-dev `
  --name evamodel

# Create containers (example for eva-foundation)
az cosmosdb sql container create `
  --account-name $cosmosAccount `
  --database-name eva-foundation `
  --name users `
  --partition-key-path "/id" `
  --throughput 400

# Add more containers as needed based on your data model
```

#### 5.3 Store Secrets in Key Vault
```powershell
$kvName = "marcokv$(Get-Date -Format 'yyyyMMdd')"

# Cosmos DB connection string
$cosmosKey = az cosmosdb keys list `
  --name $cosmosAccount `
  --resource-group EVA-Sandbox-dev `
  --type connection-strings `
  --query "connectionStrings[0].connectionString" -o tsv

az keyvault secret set `
  --vault-name $kvName `
  --name "COSMOS-CONNECTION-STRING" `
  --value $cosmosKey

# ACR credentials (if using admin)
$acrPassword = az acr credential show `
  --name $acrName `
  --query "passwords[0].value" -o tsv

az keyvault secret set `
  --vault-name $kvName `
  --name "ACR-PASSWORD" `
  --value $acrPassword

# Add Azure OpenAI keys manually
Write-Host "`n[ACTION REQUIRED] Store these secrets in Key Vault:" -ForegroundColor Yellow
Write-Host "  - AZURE-OPENAI-KEY" -ForegroundColor Yellow
Write-Host "  - AZURE-OPENAI-ENDPOINT" -ForegroundColor Yellow
Write-Host "  - FOUNDRY-API-KEY" -ForegroundColor Yellow
```

#### 5.4 Configure RBAC (if not using automated script)
```powershell
# Get managed identity details
$containerApps = @('marco-eva-brain-api', 'marco-eva-data-model', 'marco-eva-faces', 'marco-eva-roles-api')

foreach ($app in $containerApps) {
    $principalId = az containerapp show `
      --name $app `
      --resource-group EVA-Sandbox-dev `
      --query "identity.principalId" -o tsv
    
    # Grant AcrPull
    az role assignment create `
      --assignee $principalId `
      --role "AcrPull" `
      --scope "/subscriptions/MARCOSUB_ID/resourceGroups/EVA-Sandbox-dev/providers/Microsoft.ContainerRegistry/registries/$acrName"
    
    # Grant Key Vault Secrets User
    az role assignment create `
      --assignee $principalId `
      --role "Key Vault Secrets User" `
      --scope "/subscriptions/MARCOSUB_ID/resourceGroups/EVA-Sandbox-dev/providers/Microsoft.KeyVault/vaults/$kvName"
    
    # Grant Cosmos DB Data Contributor
    az role assignment create `
      --assignee $principalId `
      --role "Cosmos DB Account Reader Role" `
      --scope "/subscriptions/MARCOSUB_ID/resourceGroups/EVA-Sandbox-dev/providers/Microsoft.DocumentDB/databaseAccounts/$cosmosAccount"
}

Write-Host "`n[OK] RBAC configured for all Container Apps" -ForegroundColor Green
```

#### 5.5 Verify Container Apps
```powershell
# Check all Container Apps status
az containerapp list `
  --resource-group EVA-Sandbox-dev `
  --query "[].{Name:name, Status:properties.runningStatus, FQDN:properties.configuration.ingress.fqdn}" `
  --output table

# Test health endpoints
$apps = az containerapp list `
  --resource-group EVA-Sandbox-dev `
  --query "[].properties.configuration.ingress.fqdn" -o tsv

foreach ($fqdn in $apps) {
    Write-Host "Testing https://$fqdn ..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "https://$fqdn/health" -Method GET -TimeoutSec 10
        Write-Host "  [OK] $fqdn returned $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] $fqdn not responding yet" -ForegroundColor DarkYellow
    }
}
```

## 📊 Expected Resources (31 total)

After deployment completes, verify these resources exist:

### Compute (8 resources)
- [ ] marco-eva-brain-api (Container App)
- [ ] marco-eva-data-model (Container App)
- [ ] marco-eva-faces (Container App)
- [ ] marco-eva-roles-api (Container App)
- [ ] marco-sandbox-backend (App Service)
- [ ] marco-sandbox-enrichment (App Service)
- [ ] marco-sandbox-func (Function App)
- [ ] marco-sandbox-env (Container App Environment)

### Storage & Data (4 resources)
- [ ] marcosand<timestamp> (Storage Account)
- [ ] marcosandboxfinopshub (Storage Account)
- [ ] marco-sandbox-cosmos (Cosmos DB)
- [ ] marcoacr<timestamp> (Container Registry)

### AI/ML (6 resources)
- [ ] marco-sandbox-foundry (AI Services)
- [ ] marco-sandbox-fdry-project (Foundry Project)
- [ ] marco-sandbox-openai (Azure OpenAI)
- [ ] marco-sandbox-openai-v2 (Azure OpenAI secondary)
- [ ] marco-sandbox-aisvc (Cognitive Services)
- [ ] marco-sandbox-docint (Document Intelligence)
- [ ] marco-sandbox-search (Azure AI Search)

### Infrastructure (13 resources)
- [ ] marcokv<timestamp> (Key Vault)
- [ ] marco-sandbox-apim (API Management)
- [ ] marco-sandbox-appinsights (Application Insights)
- [ ] marco-sandbox-func-ai (Application Insights for Functions)
- [ ] marco-sandbox-law (Log Analytics Workspace)
- [ ] marco-finops-evhns (Event Hubs Namespace)
- [ ] marco-sandbox-finops-adf (Data Factory)
- [ ] marco-sandbox-asp-backend (App Service Plan)
- [ ] marco-sandbox-asp-enrichment (App Service Plan)
- [ ] marco-sandbox-asp-func (App Service Plan)

## 🔍 Verification Commands

```powershell
# Check deployment status
az deployment group list `
  --resource-group EVA-Sandbox-dev `
  --query "[0].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}" `
  --output table

# Count deployed resources
az resource list `
  --resource-group EVA-Sandbox-dev `
  --query "length(@)"

# Check costs (first week will show $0)
az consumption usage list `
  --start-date (Get-Date).AddDays(-7).ToString('yyyy-MM-dd') `
  --end-date (Get-Date).ToString('yyyy-MM-dd') | ConvertFrom-Json | Measure-Object

# View deployment outputs
az deployment group show `
  --resource-group EVA-Sandbox-dev `
  --name "eva-deployment-<timestamp>" `
  --query "properties.outputs"
```

## 💰 Expected Costs (Clean Slate Dev)

| Resource Type | SKU | Monthly Cost (CAD) |
|---|---|---|
| Container Apps (4) | 0.5 CPU, 1Gi RAM each | $55-75 |
| App Services (3) | B1 Basic | $48 |
| Cosmos DB | Serverless | $10-30 |
| ACR | Basic | $6.50 |
| Storage (2) | Standard LRS | $5 |
| Key Vault | Standard | $1 |
| APIM | Developer | $56 |
| AI Search | Basic | $89 |
| Azure OpenAI | S0 | Pay-per-call |
| Event Hubs | Standard | $11 |
| App Insights | Pay-per-GB | $5-15 |
| Log Analytics | Pay-per-GB | $5-10 |
| **TOTAL** | | **$341-391/month** |

## 🛡️ Security Checklist

- [ ] All resources use managed identities (no passwords)
- [ ] Key Vault soft delete enabled (90 days)
- [ ] TLS 1.2+ enforced on all endpoints
- [ ] HTTPS-only on all web apps
- [ ] RBAC configured (least privilege)
- [ ] Network rules configured in Key Vault (optional)
- [ ] Diagnostic logs enabled on critical resources
- [ ] Tags applied consistently (environment, owner, project)

## 📝 Post-Deployment Notes

### Update Application Settings
After deployment, update Container Apps with Key Vault references:

```powershell
# Example: Update EVA Brain API to use Key Vault secrets
az containerapp update `
  --name marco-eva-brain-api `
  --resource-group EVA-Sandbox-dev `
  --set-env-vars `
    "AZURE_OPENAI_KEY=secretref:azure-openai-key" `
    "COSMOS_KEY=secretref:cosmos-key"
```

### Import APIs to APIM
If using API Management, import OpenAPI specs for your APIs.

### Configure Monitoring
Set up alerts in Application Insights for:
- Failed requests > 5% in 5 minutes
- Response time > 1s for 95th percentile
- Exception rate > 10/minute

## 🆘 Troubleshooting

### Issue: Resource provider not registered
```powershell
az provider register --namespace Microsoft.App --wait
```

### Issue: Quota exceeded
Check subscription quotas and request increases if needed:
```powershell
az vm list-usage --location canadacentral --output table
```

### Issue: Container App fails to start
Check logs:
```powershell
az containerapp logs show `
  --name marco-eva-brain-api `
  --resource-group EVA-Sandbox-dev `
  --follow
```

### Issue: ACR image pull fails
Verify managed identity has AcrPull role:
```powershell
az role assignment list `
  --assignee <PRINCIPAL_ID> `
  --scope <ACR_RESOURCE_ID>
```

## ✅ Deployment Complete

Once all steps are complete and verified:
1. Document the new subscription details in your inventory
2. Update CI/CD pipelines to target new ACR
3. Update DNS records if using custom domains
4. Test end-to-end application flows
5. Schedule regular cost reviews

---

**Ready to deploy?** Run the automated deployment script:
```powershell
cd C:\eva-foundry\22-rg-sandbox\bicep-templates
.\Deploy-Infrastructure.ps1 -Environment dev -SubscriptionId "YOUR_MARCOSUB_ID"
```
