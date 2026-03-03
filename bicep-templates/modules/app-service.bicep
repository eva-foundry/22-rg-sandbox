// ==============================================================================
// App Service Module
// ==============================================================================

@description('Name of the App Service')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('App Service Plan resource ID')
param appServicePlanId string

@description('Linux FX version (e.g., DOCKER|registry/image:tag, PYTHON|3.11, NODE|18-lts)')
param linuxFxVersion string = ''

@description('Enable system-assigned managed identity')
param enableSystemIdentity bool = true

@description('Enable HTTPS only')
param httpsOnly bool = true

@description('App settings')
param appSettings array = []

// ==============================================================================
// RESOURCES
// ==============================================================================

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: 'app,linux'
  identity: enableSystemIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: appSettings
    }
    clientAffinityEnabled: false
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = appService.id
output name string = appService.name
output defaultHostName string = appService.properties.defaultHostName
output principalId string = enableSystemIdentity ? appService.identity.principalId : ''
