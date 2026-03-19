// ==============================================================================
// Container App Module - RBAC Fixed
// Fixes vulnerability: ACA + private ACR without RBAC role assignment
// 
// Change from container-app.bicep:
// - Added parameters for ACR name and resource group
// - Added ACR resource reference and explicit system-assigned MI
// - Added RBAC role assignment for AcrPull (CRITICAL FIX)
// 
// Reference: 19-ai-gov/kernel-engine/deploy/kernel-engine-acr-fixed.bicep
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

// ── NEW PARAMETERS for ACR RBAC ───────────────────────────────────────────

@description('(NEW) ACR name for RBAC assignment (e.g., myjpregistry) - leave empty to skip RBAC setup')
param acrName string = ''

@description('(NEW) Resource group containing the ACR - defaults to current resource group')
param acrResourceGroupName string = resourceGroup().name

// ── VARIABLES ──────────────────────────────────────────────────────────────

// Standard Azure role: AcrPull allows image pull from ACR
var acrPullRoleDefinitionId = '7f951795-a136-40b6-9b6e-7ee7f4fb2b5d'

// ==============================================================================
// RESOURCES
// ==============================================================================

// ── Container App ──────────────────────────────────────────────────────────

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

// ── ACR REFERENCE (NEW) ────────────────────────────────────────────────────
// This references the ACR resource to create the RBAC role assignment on it.
// Only created if acrName is provided (conditional).

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (!empty(acrName)) {
  name: acrName
  scope: resourceGroup(acrResourceGroupName)
}

// ── RBAC ROLE ASSIGNMENT (NEW) ─────────────────────────────────────────────
// CRITICAL FIX: Grant Container App's managed identity AcrPull permission on the ACR
// This allows the container runtime to pull images from the private registry.
//
// Without this assignment:
// - Container App has a managed identity (automatic)
// - ACR configuration is correct (explicit in registries array)
// - BUT: Image pull fails at auth check (no permissions)
//
// This resource fixes that gap by explicitly granting AcrPull role.

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(acrName) && enableSystemIdentity) {
  scope: acr
  name: guid(acr.id, containerApp.identity!.principalId, acrPullRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionId)
    principalId: containerApp.identity!.principalId
    principalType: 'ServicePrincipal'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output id string = containerApp.id

output name string = containerApp.name

output fqdn string = containerApp.properties.configuration.ingress.fqdn

output principalId string = enableSystemIdentity ? containerApp.identity!.principalId : ''

output latestRevisionFqdn string = containerApp.properties.latestRevisionFqdn

@description('(NEW) RBAC role assignment ID for AcrPull - verify this if image pull fails')
output acrPullRoleAssignmentId string = !empty(acrName) && enableSystemIdentity ? acrPullRoleAssignment.id : ''

@description('(NEW) ACR principal ID that was granted AcrPull - use for debugging')
output acrPullPrincipalId string = enableSystemIdentity ? containerApp.identity!.principalId : ''
