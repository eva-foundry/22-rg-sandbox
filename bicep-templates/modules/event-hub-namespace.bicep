// ==============================================================================
// Event Hub Namespace Module
// ==============================================================================

@description('Name of the Event Hub Namespace')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('Event Hub SKU')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Standard'

@description('Throughput units (1-20 for Standard, 1-10 for Premium)')
@minValue(1)
@maxValue(20)
param capacity int = 1

@description('Enable zone redundancy')
param zoneRedundant bool = false

@description('Enable auto-inflate')
param isAutoInflateEnabled bool = false

@description('Maximum throughput units for auto-inflate')
@minValue(0)
@maxValue(20)
param maximumThroughputUnits int = 0

@description('Enable Kafka')
param kafkaEnabled bool = true

// ==============================================================================
// RESOURCES
// ==============================================================================

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
    capacity: capacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    zoneRedundant: zoneRedundant
    isAutoInflateEnabled: isAutoInflateEnabled
    maximumThroughputUnits: isAutoInflateEnabled ? maximumThroughputUnits : 0
    kafkaEnabled: kafkaEnabled
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: '1.2'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = eventHubNamespace.id
output name string = eventHubNamespace.name
output principalId string = eventHubNamespace.identity.principalId
output serviceBusEndpoint string = eventHubNamespace.properties.serviceBusEndpoint
