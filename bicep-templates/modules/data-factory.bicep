// ==============================================================================
// Data Factory Module
// ==============================================================================

@description('Name of the Data Factory')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('Enable Git repository')
param enableGitRepository bool = false

@description('Git repository type (FactoryGitHubConfiguration or FactoryVSTSConfiguration)')
param gitRepoType string = ''

@description('Public network access')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

// ==============================================================================
// RESOURCES
// ==============================================================================

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    repoConfiguration: enableGitRepository ? {
      type: gitRepoType
    } : null
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = dataFactory.id
output name string = dataFactory.name
output principalId string = dataFactory.identity.principalId
