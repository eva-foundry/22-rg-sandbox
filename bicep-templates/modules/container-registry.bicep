// ==============================================================================
// Container Registry Module
// ==============================================================================

@description('Name of the container registry (5-50 alphanumeric chars)')
@minLength(5)
@maxLength(50)
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('Container Registry SKU')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

@description('Enable admin user')
param adminUserEnabled bool = true

@description('Enable zone redundancy (Premium SKU only)')
param zoneRedundancy bool = false

@description('Enable public network access')
param publicNetworkAccess bool = true

// ==============================================================================
// RESOURCES
// ==============================================================================

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    zoneRedundancy: (sku == 'Premium' && zoneRedundancy) ? 'Enabled' : 'Disabled'
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = containerRegistry.id
output name string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
output principalId string = containerRegistry.identity.principalId
