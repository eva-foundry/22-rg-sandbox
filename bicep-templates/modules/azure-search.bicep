// ==============================================================================
// Azure AI Search Module
// ==============================================================================

@description('Name of the Azure AI Search service')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('Search service SKU')
@allowed(['free', 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param sku string = 'basic'

@description('Number of replicas (1-12 for standard tiers)')
@minValue(1)
@maxValue(12)
param replicaCount int = 1

@description('Number of partitions (1-12 for standard tiers)')
@minValue(1)
@maxValue(12)
param partitionCount int = 1

@description('Hosting mode')
@allowed(['default', 'highDensity'])
param hostingMode string = 'default'

@description('Enable public network access')
param publicNetworkAccess bool = true

@description('Disable local authentication (use Entra ID only)')
param disableLocalAuth bool = false

// ==============================================================================
// RESOURCES
// ==============================================================================

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    replicaCount: replicaCount
    partitionCount: partitionCount
    hostingMode: hostingMode
    publicNetworkAccess: publicNetworkAccess ? 'enabled' : 'disabled'
    disableLocalAuth: disableLocalAuth
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    semanticSearch: 'disabled'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = searchService.id
output name string = searchService.name
output endpoint string = 'https://${searchService.name}.search.windows.net'
output principalId string = searchService.identity.principalId
output primaryKey string = searchService.listAdminKeys().primaryKey
