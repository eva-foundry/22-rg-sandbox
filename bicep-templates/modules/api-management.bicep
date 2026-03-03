// ==============================================================================
// API Management Module
// ==============================================================================

@description('Name of the API Management service')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('API Management SKU')
@allowed(['Consumption', 'Developer', 'Basic', 'Standard', 'Premium'])
param sku string = 'Developer'

@description('SKU capacity (number of units)')
@minValue(0)
@maxValue(12)
param skuCapacity int = 1

@description('Publisher email')
param publisherEmail string

@description('Publisher name')
param publisherName string

@description('Enable system-assigned managed identity')
param enableSystemIdentity bool = true

@description('Disable legacy TLS protocols (1.0 and 1.1)')
param disableLegacyTls bool = true

// ==============================================================================
// RESOURCES
// ==============================================================================

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: sku == 'Consumption' ? 0 : skuCapacity
  }
  identity: enableSystemIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: '${name}.azure-api.net'
        negotiateClientCertificate: false
        defaultSslBinding: true
        certificateSource: 'BuiltIn'
      }
    ]
    customProperties: disableLegacyTls ? {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
    } : {}
    virtualNetworkType: 'None'
    disableGateway: false
    apiVersionConstraint: {}
    publicNetworkAccess: 'Enabled'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = apiManagement.id
output name string = apiManagement.name
output gatewayUrl string = apiManagement.properties.gatewayUrl
output principalId string = enableSystemIdentity ? apiManagement.identity.principalId : ''
