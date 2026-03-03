// ==============================================================================
// AI Services Module (OpenAI, Foundry, Cognitive Services, Document Intelligence)
// ==============================================================================

@description('Name of the AI service')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('Kind of AI service')
@allowed(['AIServices', 'OpenAI', 'CognitiveServices', 'FormRecognizer', 'TextAnalytics', 'ComputerVision'])
param kind string = 'OpenAI'

@description('SKU name')
@allowed(['F0', 'S0', 'S1', 'S2', 'S3', 'S4'])
param sku string = 'S0'

@description('Enable system-assigned managed identity')
param enableSystemIdentity bool = true

@description('Custom subdomain name (required for some services)')
param customSubDomainName string = ''

@description('Enable public network access')
param publicNetworkAccess bool = true

@description('Disable local authentication (use Entra ID only)')
param disableLocalAuth bool = false

// ==============================================================================
// RESOURCES
// ==============================================================================

resource aiService 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: {
    name: sku
  }
  identity: enableSystemIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    customSubDomainName: !empty(customSubDomainName) ? customSubDomainName : name
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    disableLocalAuth: disableLocalAuth
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = aiService.id
output name string = aiService.name
output endpoint string = aiService.properties.endpoint
output principalId string = enableSystemIdentity ? aiService.identity.principalId : ''
output key string = aiService.listKeys().key1
