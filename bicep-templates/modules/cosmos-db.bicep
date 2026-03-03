// ==============================================================================
// Cosmos DB Account Module
// ==============================================================================

@description('Name of the Cosmos DB account')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('Default consistency level')
@allowed(['Eventual', 'ConsistentPrefix', 'Session', 'BoundedStaleness', 'Strong'])
param consistencyLevel string = 'Session'

@description('Enable automatic failover')
param enableAutomaticFailover bool = false

@description('Enable free tier')
param enableFreeTier bool = false

@description('Enable multiple write locations')
param enableMultipleWriteLocations bool = false

@description('Database account offer type')
@allowed(['Standard'])
param databaseAccountOfferType string = 'Standard'

// ==============================================================================
// RESOURCES
// ==============================================================================

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: name
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: databaseAccountOfferType
    enableFreeTier: enableFreeTier
    enableAutomaticFailover: enableAutomaticFailover
    enableMultipleWriteLocations: enableMultipleWriteLocations
    consistencyPolicy: {
      defaultConsistencyLevel: consistencyLevel
      maxStalenessPrefix: 100
      maxIntervalInSeconds: 5
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: []
    publicNetworkAccess: 'Enabled'
    enableAnalyticalStorage: false
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Local'
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = cosmosDbAccount.id
output name string = cosmosDbAccount.name
output endpoint string = cosmosDbAccount.properties.documentEndpoint
output primaryKey string = cosmosDbAccount.listKeys().primaryMasterKey
output connectionString string = cosmosDbAccount.listConnectionStrings().connectionStrings[0].connectionString
output principalId string = cosmosDbAccount.identity.principalId
