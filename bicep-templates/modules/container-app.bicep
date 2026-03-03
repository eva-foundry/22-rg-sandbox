// ==============================================================================
// Container App Module
// ==============================================================================

@description('Name of the Container App')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object = {}

@description('Container App Environment resource ID')
param containerAppEnvironmentId string

@description('Container image (registry/image:tag)')
param containerImage string

@description('Container registry server')
param containerRegistryServer string

@description('Target port for ingress')
param targetPort int = 80

@description('Enable external ingress')
param externalIngress bool = true

@description('CPU allocation (e.g., 0.25, 0.5, 1.0)')
param cpu string = '0.5'

@description('Memory allocation (e.g., 0.5Gi, 1Gi, 2Gi)')
param memory string = '1Gi'

@description('Minimum replicas')
@minValue(0)
@maxValue(30)
param minReplicas int = 1

@description('Maximum replicas')
@minValue(1)
@maxValue(30)
param maxReplicas int = 3

@description('Environment variables')
param environmentVariables array = []

@description('Secrets for environment variables')
param secrets array = []

@description('Enable system-assigned managed identity')
param enableSystemIdentity bool = true

// ==============================================================================
// RESOURCES
// ==============================================================================

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: tags
  identity: enableSystemIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    managedEnvironmentId: containerAppEnvironmentId
    configuration: {
      ingress: {
        external: externalIngress
        targetPort: targetPort
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: containerRegistryServer
          identity: 'system'
        }
      ]
      secrets: secrets
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: name
          image: containerImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: environmentVariables
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = containerApp.id
output name string = containerApp.name
output fqdn string = containerApp.properties.configuration.ingress.fqdn
output principalId string = enableSystemIdentity ? containerApp.identity.principalId : ''
output latestRevisionFqdn string = containerApp.properties.latestRevisionFqdn
