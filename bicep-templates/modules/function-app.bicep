// ==============================================================================
// Function App Module
// ==============================================================================

@description('Name of the Function App')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('App Service Plan resource ID')
param appServicePlanId string

@description('Storage Account name for function content')
param storageAccountName string

@description('Application Insights connection string')
param applicationInsightsConnectionString string

@description('Enable system-assigned managed identity')
param enableSystemIdentity bool = true

@description('Function runtime (dotnet, node, python, java)')
param runtime string = 'python'

@description('Runtime version (e.g., 3.11 for Python, 18 for Node)')
param runtimeVersion string = '3.11'

@description('Enable HTTPS only')
param httpsOnly bool = true

// ==============================================================================
// VARIABLES
// ==============================================================================

var functionWorkerRuntime = runtime
var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value}'

// ==============================================================================
// RESOURCES
// ==============================================================================

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: enableSystemIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    siteConfig: {
      linuxFxVersion: '${toUpper(runtime)}|${runtimeVersion}'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageAccountConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageAccountConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(name)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
      ]
    }
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = functionApp.id
output name string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName
output principalId string = enableSystemIdentity ? functionApp.identity.principalId : ''
