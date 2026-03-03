// ==============================================================================
// App Service Plan Module
// ==============================================================================

@description('Name of the App Service Plan')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('App Service Plan SKU (e.g., B1, S1, P1v2)')
param sku string = 'B1'

@description('Operating system kind')
@allowed(['linux', 'windows'])
param kind string = 'linux'

@description('Reserved for Linux')
param reserved bool = true

@description('Enable zone redundancy (Premium SKU only)')
param zoneRedundant bool = false

// ==============================================================================
// RESOURCES
// ==============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: {
    name: sku
  }
  properties: {
    reserved: reserved
    zoneRedundant: zoneRedundant
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = appServicePlan.id
output name string = appServicePlan.name
