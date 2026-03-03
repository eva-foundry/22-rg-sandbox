// ==============================================================================
// Application Insights Module
// ==============================================================================

@description('Name of the Application Insights resource')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('Log Analytics Workspace Resource ID')
param workspaceResourceId string

@description('Application type')
@allowed(['web', 'other'])
param applicationType string = 'web'

@description('Data retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('Disable IP masking')
param disableIpMasking bool = false

// ==============================================================================
// RESOURCES
// ==============================================================================

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: workspaceResourceId
    RetentionInDays: retentionInDays
    DisableIpMasking: disableIpMasking
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = applicationInsights.id
output name string = applicationInsights.name
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output connectionString string = applicationInsights.properties.ConnectionString
