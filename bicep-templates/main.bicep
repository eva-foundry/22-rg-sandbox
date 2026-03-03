// ==============================================================================
// Main Bicep Template - Marco EVA Sandbox Infrastructure
// ==============================================================================
// Purpose: Orchestrates deployment of all marco* Azure resources
// Version: 1.0.0
// Last Updated: 2026-03-03
// ==============================================================================

targetScope = 'resourceGroup'

// ==============================================================================
// PARAMETERS
// ==============================================================================

@description('Primary Azure region for resources')
param location string = 'canadacentral'

@description('Secondary Azure region (for AI services)')
param secondaryLocation string = 'canadaeast'

@description('Environment suffix (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Resource name prefix')
param resourcePrefix string = 'marco'

@description('Owner email for resource tagging')
param ownerEmail string = 'marco.presta@hrsdc-rhdcc.gc.ca'

@description('Project name for resource tagging')
param projectName string = 'eva-sandbox'

@description('Deployment timestamp (YYYYMMDD-HHMM format)')
param deploymentTimestamp string = utcNow('yyyyMMdd-HHmm')

// Container image tags
@description('EVA Brain API container image tag')
param evaBrainApiImageTag string = 'sprint7-epic-scope'

@description('EVA Data Model API container image tag')
param evaDataModelImageTag string = '20260302-1300'

@description('EVA Faces container image tag')
param evaFacesImageTag string = '20260226-v16'

@description('EVA Roles API container image tag')
param evaRolesApiImageTag string = 'latest'

// SKU overrides
@description('API Management SKU')
@allowed(['Consumption', 'Developer', 'Basic', 'Standard', 'Premium'])
param apimSku string = 'Developer'

@description('Azure Search SKU')
@allowed(['free', 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param searchSku string = 'basic'

@description('App Service Plan SKU for backend')
param backendPlanSku string = 'B1'

@description('Container Apps CPU allocation')
param containerAppCpu string = '0.5'

@description('Container Apps memory allocation')
param containerAppMemory string = '1Gi'

// ==============================================================================
// VARIABLES
// ==============================================================================

var commonTags = {
  environment: environment
  owner: ownerEmail
  project: projectName
  deployedBy: 'bicep'
  deployedOn: deploymentTimestamp
}

var namingConvention = {
  storageAccount: toLower('${resourcePrefix}sand${replace(deploymentTimestamp, '-', '')}')
  containerRegistry: toLower('${resourcePrefix}sandacr${replace(deploymentTimestamp, '-', '')}')
  keyVault: '${resourcePrefix}sandkv${replace(deploymentTimestamp, '-', '')}'
  cosmosDb: '${resourcePrefix}-sandbox-cosmos'
  containerAppEnv: '${resourcePrefix}-sandbox-env'
  aiServices: '${resourcePrefix}-sandbox-foundry'
  openAI: '${resourcePrefix}-sandbox-openai'
  search: '${resourcePrefix}-sandbox-search'
  apim: '${resourcePrefix}-sandbox-apim'
}

// ==============================================================================
// RESOURCE DEPLOYMENTS
// ==============================================================================

// --- Foundation Layer (0 dependencies) ---

// Log Analytics Workspace (required by Application Insights and Container Apps)
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    name: '${resourcePrefix}-sandbox-logs'
    location: location
    tags: commonTags
    retentionInDays: 90
  }
}

// Application Insights
module appInsights 'modules/application-insights.bicep' = {
  name: 'deploy-app-insights'
  params: {
    name: '${resourcePrefix}-sandbox-appinsights'
    location: location
    tags: union(commonTags, {
      Component: 'Monitoring'
    })
    workspaceResourceId: logAnalytics.outputs.id
    retentionInDays: 90
  }
}

// Storage Accounts
module storageMain 'modules/storage-account.bicep' = {
  name: 'deploy-storage-main'
  params: {
    name: namingConvention.storageAccount
    location: location
    tags: commonTags
    sku: 'Standard_LRS'
    kind: 'StorageV2'
  }
}

module storageFinOps 'modules/storage-account.bicep' = {
  name: 'deploy-storage-finops'
  params: {
    name: '${resourcePrefix}sandboxfinopshub'
    location: location
    tags: union(commonTags, {
      purpose: 'finops-hub'
    })
    sku: 'Standard_LRS'
    kind: 'StorageV2'
  }
}

// Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'deploy-acr'
  params: {
    name: namingConvention.containerRegistry
    location: location
    tags: commonTags
    sku: 'Basic'
    adminUserEnabled: true
  }
}

// Key Vault
module keyVault 'modules/key-vault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    name: namingConvention.keyVault
    location: location
    tags: commonTags
    sku: 'standard'
    enableSoftDelete: true
    enablePurgeProtection: false
    tenantId: subscription().tenantId
  }
}

// Cosmos DB
module cosmosDb 'modules/cosmos-db.bicep' = {
  name: 'deploy-cosmos'
  params: {
    name: namingConvention.cosmosDb
    location: location
    tags: commonTags
    consistencyLevel: 'Session'
    enableFreeTier: false
  }
}

// AI Services - Foundry (canadaeast)
module aiServicesFoundry 'modules/ai-services.bicep' = {
  name: 'deploy-ai-foundry'
  params: {
    name: namingConvention.aiServices
    location: secondaryLocation
    tags: commonTags
    kind: 'AIServices'
    sku: 'S0'
    enableSystemIdentity: true
  }
}

// Azure OpenAI Primary
module openAIPrimary 'modules/ai-services.bicep' = {
  name: 'deploy-openai-primary'
  params: {
    name: namingConvention.openAI
    location: secondaryLocation
    tags: commonTags
    kind: 'OpenAI'
    sku: 'S0'
    enableSystemIdentity: true
  }
}

// Azure OpenAI Secondary
module openAISecondary 'modules/ai-services.bicep' = {
  name: 'deploy-openai-secondary'
  params: {
    name: '${namingConvention.openAI}-v2'
    location: secondaryLocation
    tags: commonTags
    kind: 'OpenAI'
    sku: 'S0'
    enableSystemIdentity: true
  }
}

// Cognitive Services Multi-Service
module cognitiveServices 'modules/ai-services.bicep' = {
  name: 'deploy-cognitive-services'
  params: {
    name: '${resourcePrefix}-sandbox-aisvc'
    location: location
    tags: commonTags
    kind: 'CognitiveServices'
    sku: 'S0'
    enableSystemIdentity: true
    customSubDomainName: '${resourcePrefix}-sandbox-aisvc'
  }
}

// Document Intelligence (Form Recognizer)
module documentIntelligence 'modules/ai-services.bicep' = {
  name: 'deploy-document-intelligence'
  params: {
    name: '${resourcePrefix}-sandbox-docint'
    location: location
    tags: commonTags
    kind: 'FormRecognizer'
    sku: 'S0'
    enableSystemIdentity: true
  }
}

// Azure AI Search
module search 'modules/azure-search.bicep' = {
  name: 'deploy-search'
  params: {
    name: namingConvention.search
    location: location
    tags: commonTags
    sku: searchSku
    replicaCount: 1
    partitionCount: 1
  }
}

// Event Hubs Namespace
module eventHubNamespace 'modules/event-hub-namespace.bicep' = {
  name: 'deploy-eventhub'
  params: {
    name: '${resourcePrefix}-finops-evhns'
    location: location
    tags: commonTags
    sku: 'Standard'
    capacity: 1
    isAutoInflateEnabled: false
    zoneRedundant: true
  }
}

// Data Factory
module dataFactory 'modules/data-factory.bicep' = {
  name: 'deploy-adf'
  params: {
    name: '${resourcePrefix}-sandbox-finops-adf'
    location: location
    tags: commonTags
  }
}

// --- Compute Layer (requires foundation) ---

// Container App Environment
module containerAppEnv 'modules/container-app-environment.bicep' = {
  name: 'deploy-container-env'
  params: {
    name: namingConvention.containerAppEnv
    location: location
    tags: commonTags
    logAnalyticsWorkspaceId: logAnalytics.outputs.customerId
    logAnalyticsWorkspaceKey: logAnalytics.outputs.sharedKey
  }
}

// Container Apps
module containerAppBrainApi 'modules/container-app.bicep' = {
  name: 'deploy-container-brain-api'
  params: {
    name: '${resourcePrefix}-eva-brain-api'
    location: location
    tags: commonTags
    containerAppEnvironmentId: containerAppEnv.outputs.id
    containerImage: '${containerRegistry.outputs.loginServer}/eva-brain-api:${evaBrainApiImageTag}'
    containerRegistryServer: containerRegistry.outputs.loginServer
    targetPort: 8001
    externalIngress: true
    cpu: containerAppCpu
    memory: containerAppMemory
    minReplicas: 1
    maxReplicas: 3
    environmentVariables: [
      {
        name: 'COSMOS_ENDPOINT'
        value: cosmosDb.outputs.endpoint
      }
      {
        name: 'COSMOS_KEY'
        secretRef: 'cosmos-key'
      }
      {
        name: 'AZURE_OPENAI_ENDPOINT'
        value: openAIPrimary.outputs.endpoint
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsights.outputs.connectionString
      }
    ]
    secrets: [
      {
        name: 'cosmos-key'
        value: cosmosDb.outputs.primaryKey
      }
    ]
  }
  dependsOn: [
    containerRegistry
  ]
}

module containerAppDataModel 'modules/container-app.bicep' = {
  name: 'deploy-container-data-model'
  params: {
    name: '${resourcePrefix}-eva-data-model'
    location: location
    tags: commonTags
    containerAppEnvironmentId: containerAppEnv.outputs.id
    containerImage: '${containerRegistry.outputs.loginServer}/eva-data-model-api:${evaDataModelImageTag}'
    containerRegistryServer: containerRegistry.outputs.loginServer
    targetPort: 8010
    externalIngress: true
    cpu: containerAppCpu
    memory: containerAppMemory
    minReplicas: 1
    maxReplicas: 1
    environmentVariables: [
      {
        name: 'COSMOS_URL'
        value: cosmosDb.outputs.endpoint
      }
      {
        name: 'COSMOS_KEY'
        secretRef: 'cosmos-key'
      }
      {
        name: 'MODEL_DB_NAME'
        value: 'eva-data-model'
      }
    ]
    secrets: [
      {
        name: 'cosmos-key'
        value: cosmosDb.outputs.primaryKey
      }
    ]
  }
  dependsOn: [
    containerRegistry
  ]
}

module containerAppFaces 'modules/container-app.bicep' = {
  name: 'deploy-container-faces'
  params: {
    name: '${resourcePrefix}-eva-faces'
    location: location
    tags: commonTags
    containerAppEnvironmentId: containerAppEnv.outputs.id
    containerImage: '${containerRegistry.outputs.loginServer}/eva-faces:${evaFacesImageTag}'
    containerRegistryServer: containerRegistry.outputs.loginServer
    targetPort: 80
    externalIngress: true
    cpu: containerAppCpu
    memory: containerAppMemory
    minReplicas: 1
    maxReplicas: 3
    environmentVariables: []
    secrets: []
  }
  dependsOn: [
    containerRegistry
  ]
}

module containerAppRolesApi 'modules/container-app.bicep' = {
  name: 'deploy-container-roles-api'
  params: {
    name: '${resourcePrefix}-eva-roles-api'
    location: location
    tags: commonTags
    containerAppEnvironmentId: containerAppEnv.outputs.id
    containerImage: '${containerRegistry.outputs.loginServer}/eva-roles-api:${evaRolesApiImageTag}'
    containerRegistryServer: containerRegistry.outputs.loginServer
    targetPort: 8002
    externalIngress: true
    cpu: containerAppCpu
    memory: containerAppMemory
    minReplicas: 1
    maxReplicas: 3
    environmentVariables: []
    secrets: []
  }
  dependsOn: [
    containerRegistry
  ]
}

// App Service Plans
module appServicePlanBackend 'modules/app-service-plan.bicep' = {
  name: 'deploy-asp-backend'
  params: {
    name: '${resourcePrefix}-sandbox-asp-backend'
    location: location
    tags: commonTags
    sku: backendPlanSku
    kind: 'linux'
    reserved: true
  }
}

module appServicePlanEnrichment 'modules/app-service-plan.bicep' = {
  name: 'deploy-asp-enrichment'
  params: {
    name: '${resourcePrefix}-sandbox-asp-enrichment'
    location: location
    tags: commonTags
    sku: backendPlanSku
    kind: 'linux'
    reserved: true
  }
}

module appServicePlanFunctions 'modules/app-service-plan.bicep' = {
  name: 'deploy-asp-functions'
  params: {
    name: '${resourcePrefix}-sandbox-asp-func'
    location: location
    tags: commonTags
    sku: backendPlanSku
    kind: 'linux'
    reserved: true
  }
}

// App Services
module appServiceBackend 'modules/app-service.bicep' = {
  name: 'deploy-app-backend'
  params: {
    name: '${resourcePrefix}-sandbox-backend'
    location: location
    tags: commonTags
    appServicePlanId: appServicePlanBackend.outputs.id
    linuxFxVersion: 'DOCKER|${containerRegistry.outputs.loginServer}/backend:latest'
    enableSystemIdentity: true
    appSettings: [
      {
        name: 'DOCKER_REGISTRY_SERVER_URL'
        value: 'https://${containerRegistry.outputs.loginServer}'
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsights.outputs.connectionString
      }
    ]
  }
}

module appServiceEnrichment 'modules/app-service.bicep' = {
  name: 'deploy-app-enrichment'
  params: {
    name: '${resourcePrefix}-sandbox-enrichment'
    location: location
    tags: commonTags
    appServicePlanId: appServicePlanEnrichment.outputs.id
    linuxFxVersion: 'PYTHON|3.11'
    enableSystemIdentity: true
    appSettings: [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsights.outputs.connectionString
      }
    ]
  }
}

// Function App
module functionApp 'modules/function-app.bicep' = {
  name: 'deploy-function-app'
  params: {
    name: '${resourcePrefix}-sandbox-func'
    location: location
    tags: commonTags
    appServicePlanId: appServicePlanFunctions.outputs.id
    storageAccountName: storageMain.outputs.name
    applicationInsightsConnectionString: appInsights.outputs.connectionString
    enableSystemIdentity: true
    runtime: 'python'
    runtimeVersion: '3.11'
  }
}

// API Management
module apiManagement 'modules/api-management.bicep' = {
  name: 'deploy-apim'
  params: {
    name: namingConvention.apim
    location: location
    tags: commonTags
    sku: apimSku
    publisherEmail: ownerEmail
    publisherName: 'Marco Presta'
    enableSystemIdentity: true
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output resourceGroupName string = resourceGroup().name
output location string = location

// Storage
output storageAccountName string = storageMain.outputs.name
output storageAccountId string = storageMain.outputs.id
output finOpsStorageAccountName string = storageFinOps.outputs.name

// Container Registry
output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

// Key Vault
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri

// Cosmos DB
output cosmosDbAccountName string = cosmosDb.outputs.name
output cosmosDbEndpoint string = cosmosDb.outputs.endpoint

// AI Services
output aiServicesFoundryEndpoint string = aiServicesFoundry.outputs.endpoint
output openAIPrimaryEndpoint string = openAIPrimary.outputs.endpoint
output openAISecondaryEndpoint string = openAISecondary.outputs.endpoint
output searchServiceEndpoint string = search.outputs.endpoint

// Container Apps
output brainApiFqdn string = containerAppBrainApi.outputs.fqdn
output dataModelApiFqdn string = containerAppDataModel.outputs.fqdn
output facesFqdn string = containerAppFaces.outputs.fqdn
output rolesApiFqdn string = containerAppRolesApi.outputs.fqdn

// API Management
output apimGatewayUrl string = apiManagement.outputs.gatewayUrl

// Monitoring
output applicationInsightsName string = appInsights.outputs.name
output applicationInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey
