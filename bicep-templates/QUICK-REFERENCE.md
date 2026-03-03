# Marco EVA Sandbox - Quick Reference Guide

## Common Operations

### Quick Deployment (Automated)

```powershell
# Deploy to dev environment
.\Deploy-Infrastructure.ps1 -Environment dev

# Deploy to prod environment
.\Deploy-Infrastructure.ps1 -Environment prod -SubscriptionId "YOUR_SUB_ID"

# Dry run (what-if analysis)
.\Deploy-Infrastructure.ps1 -Environment dev -WhatIf

# Skip post-deployment steps
.\Deploy-Infrastructure.ps1 -Environment dev -SkipPostDeployment
```

### Manual Deployment Commands

```powershell
# Set variables
$rg = "EVA-Sandbox-dev"
$env = "dev"
$ts = Get-Date -Format "yyyyMMdd-HHmm"

# Validate
az deployment group validate --resource-group $rg --template-file main.bicep --parameters "parameters.$env.json" --parameters deploymentTimestamp=$ts

# What-if
az deployment group what-if --resource-group $rg --template-file main.bicep --parameters "parameters.$env.json" --parameters deploymentTimestamp=$ts

# Deploy
az deployment group create --resource-group $rg --template-file main.bicep --parameters "parameters.$env.json" --parameters deploymentTimestamp=$ts --name "eva-$ts"

# Get outputs
az deployment group show --resource-group $rg --name "eva-$ts" --query properties.outputs --output json
```

### Container App Operations

```powershell
# List all container apps
az containerapp list --resource-group $rg --output table

# Show specific app
az containerapp show --resource-group $rg --name marco-eva-brain-api

# Update image
az containerapp update --resource-group $rg --name marco-eva-brain-api --image "myacr.azurecr.io/eva-brain-api:new-tag"

# Scale app
az containerapp update --resource-group $rg --name marco-eva-brain-api --min-replicas 2 --max-replicas 10

# View logs
az containerapp logs show --resource-group $rg --name marco-eva-brain-api --follow

# List revisions
az containerapp revision list --resource-group $rg --name marco-eva-brain-api --output table

# Restart app
az containerapp revision restart --resource-group $rg --name marco-eva-brain-api --revision <revision-name>
```

### Container Registry Operations

```powershell
# Get ACR name
$acrName = az deployment group show --resource-group $rg --name "eva-$ts" --query properties.outputs.containerRegistryName.value -o tsv

# Login to ACR
az acr login --name $acrName

# List images
az acr repository list --name $acrName --output table

# Show image tags
az acr repository show-tags --name $acrName --repository eva-brain-api --output table

# Import image from another registry
az acr import --name $acrName --source marcosandacr20260203.azurecr.io/eva-brain-api:sprint7-epic-scope --image eva-brain-api:sprint7-epic-scope

# Delete image
az acr repository delete --name $acrName --image eva-brain-api:old-tag --yes
```

### Cosmos DB Operations

```powershell
# Get Cosmos account name
$cosmosName = az deployment group show --resource-group $rg --name "eva-$ts" --query properties.outputs.cosmosDbAccountName.value -o tsv

# List databases
az cosmosdb sql database list --account-name $cosmosName --resource-group $rg --output table

# Create database
az cosmosdb sql database create --account-name $cosmosName --resource-group $rg --name "eva-data-model"

# Create container
az cosmosdb sql container create --account-name $cosmosName --resource-group $rg --database-name "eva-data-model" --name "endpoints" --partition-key-path "/id" --throughput 400

# List containers
az cosmosdb sql container list --account-name $cosmosName --resource-group $rg --database-name "eva-data-model" --output table

# Get connection string
az cosmosdb keys list --name $cosmosName --resource-group $rg --type connection-strings --output json
```

### Key Vault Operations

```powershell
# Get Key Vault name
$kvName = az deployment group show --resource-group $rg --name "eva-$ts" --query properties.outputs.keyVaultName.value -o tsv

# List secrets
az keyvault secret list --vault-name $kvName --output table

# Set secret
az keyvault secret set --vault-name $kvName --name "MY-SECRET" --value "my-secret-value"

# Get secret
az keyvault secret show --vault-name $kvName --name "MY-SECRET" --query value -o tsv

# Delete secret
az keyvault secret delete --vault-name $kvName --name "MY-SECRET"

# Grant access to principal
az role assignment create --assignee <object-id> --role "Key Vault Secrets User" --scope "/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.KeyVault/vaults/$kvName"
```

### API Management Operations

```powershell
# Get APIM name
$apimName = az deployment group show --resource-group $rg --name "eva-$ts" --query 'properties.outputs.apimGatewayUrl.value' -o tsv | ForEach-Object { $_.Split('/')[2].Split('.')[0] }

# List APIs
az apim api list --resource-group $rg --service-name $apimName --output table

# Import OpenAPI spec
az apim api import --resource-group $rg --service-name $apimName --path "/data-model" --specification-url "https://myapi.com/openapi.json" --specification-format OpenApiJson --display-name "EVA Data Model API"

# Create subscription
az apim subscription create --resource-group $rg --service-name $apimName --name "dev-subscription" --scope "/apis"

# List subscriptions
az apim subscription list --resource-group $rg --service-name $apimName --output table

# Get subscription key
az apim subscription show --resource-group $rg --service-name $apimName --subscription-id <sub-id> --query primaryKey -o tsv
```

### Monitoring & Logs

```powershell
# Get Application Insights name
$appInsightsName = az deployment group show --resource-group $rg --name "eva-$ts" --query properties.outputs.applicationInsightsName.value -o tsv

# Get instrumentation key
$instrumentationKey = az monitor app-insights component show --resource-group $rg --app $appInsightsName --query instrumentationKey -o tsv

# Get connection string
$connectionString = az monitor app-insights component show --resource-group $rg --app $appInsightsName --query connectionString -o tsv

# Query logs (KQL)
az monitor app-insights query --app $appInsightsName --analytics-query "requests | where timestamp > ago(1h) | summarize count() by resultCode"

# View live metrics
az monitor app-insights component show --resource-group $rg --app $appInsightsName --query liveMetricStreamUrl -o tsv
```

### Cost Management

```powershell
# Show current costs
az consumption usage list --start-date (Get-Date).AddDays(-30).ToString("yyyy-MM-dd") --end-date (Get-Date).ToString("yyyy-MM-dd") | ConvertFrom-Json | Group-Object instanceName | Select-Object Name, @{N="Cost";E={($_.Group | Measure-Object -Property pretaxCost -Sum).Sum}}

# Export cost data
az costmanagement query --type Usage --dataset-filter "{\"and\":[{\"dimensions\":{\"name\":\"ResourceGroupName\",\"operator\":\"In\",\"values\":[\"$rg\"]}}]}" --timeframe MonthToDate

# Set budget alert (requires Cost Management API)
az consumption budget create --resource-group $rg --budget-name "eva-monthly-budget" --amount 500 --time-grain Monthly --start-date (Get-Date).ToString("yyyy-MM-01")
```

### RBAC Management

```powershell
# List role assignments for resource group
az role assignment list --resource-group $rg --output table

# Grant role to user
az role assignment create --assignee user@domain.com --role "Contributor" --resource-group $rg

# Grant role to managed identity
az role assignment create --assignee <principal-id> --role "Storage Blob Data Contributor" --scope "/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$storageAccount"

# List available roles
az role definition list --query "[].{Name:name, Description:description}" --output table

# Create custom role (from JSON file)
az role definition create --role-definition custom-role.json
```

### Cleanup & Teardown

```powershell
# Delete entire resource group (DESTRUCTIVE)
az group delete --name $rg --yes --no-wait

# Delete specific resources
az containerapp delete --resource-group $rg --name marco-eva-brain-api --yes
az cosmosdb delete --resource-group $rg --name $cosmosName --yes

# List all resources before deletion
az resource list --resource-group $rg --output table

# Export before deletion (backup)
az group export --resource-group $rg --output json > "backup-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
```

### Health Checks

```powershell
# Check all Container Apps health
az containerapp list --resource-group $rg --query "[].{Name:name, Status:properties.runningStatus, FQDN:properties.configuration.ingress.fqdn}" --output table

# Test endpoint
$fqdn = az containerapp show --resource-group $rg --name marco-eva-data-model --query properties.configuration.ingress.fqdn -o tsv
curl "https://$fqdn/health"

# Check resource health
az resource list --resource-group $rg --query "[].{Name:name, Type:type, Location:location, ProvisioningState:provisioningState}" --output table
```

### Debugging

```powershell
# View deployment errors
az deployment group operation list --resource-group $rg --name "eva-$ts" --query "[?properties.provisioningState=='Failed']" --output table

# Show specific operation details
az deployment group operation show --resource-group $rg --name "eva-$ts" --operation-id <operation-id>

# Enable diagnostic logs
az monitor diagnostic-settings create --resource <resource-id> --name "send-to-log-analytics" --workspace <workspace-id> --logs '[{"category":"ContainerAppConsoleLogs","enabled":true}]'

# Stream container logs
az containerapp logs show --resource-group $rg --name marco-eva-brain-api --follow --tail 100
```

---

## Environment Variables Reference

### Container Apps - Common Variables

```bash
# Cosmos DB
COSMOS_ENDPOINT=https://marco-sandbox-cosmos.documents.azure.com:443/
COSMOS_KEY=<from-key-vault>
COSMOS_DATABASE_NAME=eva-data-model

# Azure OpenAI
AZURE_OPENAI_ENDPOINT=https://marco-sandbox-openai.openai.azure.com/
AZURE_OPENAI_KEY=<from-key-vault>
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4

# Application Insights
APPLICATIONINSIGHTS_CONNECTION_STRING=<from-outputs>

# Managed Identity
AZURE_CLIENT_ID=<system-assigned-principal-id>
```

### App Service / Function Apps - Common Settings

```bash
# Storage
AzureWebJobsStorage=<connection-string>
WEBSITE_CONTENTAZUREFILECONNECTIONSTRING=<connection-string>
WEBSITE_CONTENTSHARE=<function-app-name>

# Functions Runtime
FUNCTIONS_EXTENSION_VERSION=~4
FUNCTIONS_WORKER_RUNTIME=python

# Monitoring
APPLICATIONINSIGHTS_CONNECTION_STRING=<from-outputs>
```

---

## Troubleshooting Decision Tree

### Container App Won't Start

1. Check logs: `az containerapp logs show --resource-group $rg --name <app-name> --follow`
2. Verify image exists: `az acr repository show-tags --name $acrName --repository <image-name>`
3. Check ACR permissions: `az role assignment list --assignee <principal-id> --scope <acr-resource-id>`
4. Verify environment variables: `az containerapp show --resource-group $rg --name <app-name> --query properties.template.containers[0].env`

### Cosmos DB Connection Errors

1. Verify endpoint: `az cosmosdb show --resource-group $rg --name $cosmosName --query documentEndpoint`
2. Test key: `az cosmosdb keys list --resource-group $rg --name $cosmosName --type keys`
3. Check RBAC: `az cosmosdb sql role assignment list --resource-group $rg --account-name $cosmosName`
4. Verify network rules: `az cosmosdb show --resource-group $rg --name $cosmosName --query ipRules`

### Key Vault Access Denied

1. Check managed identity: `az containerapp show --resource-group $rg --name <app-name> --query identity.principalId`
2. Verify RBAC: `az role assignment list --assignee <principal-id> --scope <kv-resource-id>`
3. Check Key Vault firewall: `az keyvault show --name $kvName --query properties.networkAcls`

### Deployment Timeout

- API Management: Normal, takes 30-40 minutes
- Container Apps: Check logs for CrashLoopBackOff
- Cosmos DB: Check quotas in subscription

---

**Document Version**: 1.0.0  
**Last Updated**: March 3, 2026
