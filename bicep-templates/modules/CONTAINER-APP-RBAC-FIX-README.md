# Container App RBAC Fix - 22-rg-sandbox Module

**Status**: COMPLETE  
**Date**: 2026-03-14  
**Impact**: Workspace-wide (generic module used by multiple projects)  
**Priority**: HIGH (blocks private ACR deployments)

---

## Problem Statement

The original `container-app.bicep` module has a critical gap in authentication for private Azure Container Registry (ACR) deployments:

### Symptom
When deploying a Container App that pulls images from a **private ACR**, the deployment reaches "Failed" state with:
```
Image pull authentication failed: unauthorized
```

### Root Cause
The module declares system-assigned managed identity for ACR authentication:
```bicep
registries: [
  {
    server: containerRegistryServer
    identity: 'system'  // ← Tells ACA to use system MI
  }
]
```

**BUT** the module does NOT create the `AcrPull` RBAC role assignment that grants the managed identity permission to pull images from the ACR.

### The Missing Link
```
Container App (created) → System MI (created automatically)
   → registry config (created) → BUT: No RBAC permission granted ❌
   → Image pull auth check fails ❌
```

---

## The Fix

Three additions to the module:

### 1. New Parameters (for ACR)
```bicep
@description('ACR name for RBAC assignment (e.g., myjpregistry) - leave empty to skip RBAC setup')
param acrName string = ''

@description('Resource group containing the ACR - defaults to current resource group')
param acrResourceGroupName string = resourceGroup().name
```

### 2. ACR Resource Reference
```bicep
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (!empty(acrName)) {
  name: acrName
  scope: resourceGroup(acrResourceGroupName)
}
```

Purpose: Template needs to reference the ACR to create RBAC assignment on it.

### 3. RBAC Role Assignment (CRITICAL)
```bicep
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(acrName) && enableSystemIdentity) {
  scope: acr
  name: guid(acr.id, containerApp.identity!.principalId, acrPullRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951795-a136-40b6-9b6e-7ee7f4fb2b5d')
    principalId: containerApp.identity!.principalId
    principalType: 'ServicePrincipal'
  }
}
```

**Role ID**: `7f951795-a136-40b6-9b6e-7ee7f4fb2b5d` (AcrPull - standard Azure role)

---

## Usage

### Deploy with Private ACR
```bicep
module myApp 'modules/container-app-rbac-fixed.bicep' = {
  name: 'deployment-myapp'
  params: {
    name: 'myapp'
    location: location
    containerAppEnvironmentId: caEnvironmentId
    containerImage: 'myregistry.azurecr.io/myapp:latest'
    containerRegistryServer: 'myregistry.azurecr.io'
    acrName: 'myregistry'                    // ← NEW: Required for RBAC
    acrResourceGroupName: 'my-resource-group' // ← NEW: Optional (defaults to current RG)
    enableSystemIdentity: true
    environmentVariables: [
      {
        name: 'ENVIRONMENT'
        value: 'production'
      }
    ]
  }
}
```

### Deploy with Public Registry (No RBAC Needed)
```bicep
module myApp 'modules/container-app-rbac-fixed.bicep' = {
  name: 'deployment-myapp'
  params: {
    name: 'myapp'
    location: location
    containerAppEnvironmentId: caEnvironmentId
    containerImage: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    containerRegistryServer: 'mcr.microsoft.com' // Public registry
    // acrName: ''  ← Leave empty for public registries
    enableSystemIdentity: true
  }
}
```

---

## Migration Path

### Step 1: Replace Module Reference
**Old**:
```bicep
module myApp 'modules/container-app.bicep' = {
```

**New**:
```bicep
module myApp 'modules/container-app-rbac-fixed.bicep' = {
```

### Step 2: Add ACR Parameters (if using private ACR)
```bicep
acrName: 'myjpregistry'
acrResourceGroupName: resourceGroup().name
```

### Step 3: Deploy and Verify
```powershell
# Redeploy with fixed module
az deployment group create \
  -g MyResourceGroup \
  --template-file main.bicep \
  --parameters myParam=value

# Verify RBAC role assignment exists
az role assignment list \
  --resource-group MyResourceGroup \
  --resource myjpregistry \
  --query "[?principalType=='ServicePrincipal']"
```

Expected output: One entry with `roleDefinitionName: "AcrPull"`

---

## New Outputs

The fixed module adds verification outputs:

| Output | Purpose | Example |
|--------|---------|---------|
| `acrPullRoleAssignmentId` | RBAC assignment ID for verification | `/subscriptions/.../roleAssignments/abc123` |
| `acrPullPrincipalId` | Managed identity that was granted permission | `12345678-1234-1234-1234-123456789abc` |

### Use for Debugging
```powershell
# Get deployment outputs
$outputs = az deployment group show \
  -g MyResourceGroup \
  --name myDeploymentName \
  --query properties.outputs

# Verify RBAC assignment exists
$roleAssignmentId = $outputs.acrPullRoleAssignmentId.value
az resource show --id $roleAssignmentId

# Expected: Role assignment properties for the Container App's MI on the ACR
```

---

## Comparison: Old vs. New

### Old Version (Vulnerable)
```bicep
registries: [
  {
    server: containerRegistryServer
    identity: 'system'  // ← Creates auth config but NO permissions
  }
]
// Result: Image pull fails at auth check ❌
```

### New Version (Fixed)
```bicep
// 1. Reference the ACR resource
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (!empty(acrName)) {
  name: acrName
  scope: resourceGroup(acrResourceGroupName)
}

// 2. Define explicit managed identity
identity: enableSystemIdentity ? {
  type: 'SystemAssigned'
} : null

// 3. Create RBAC role assignment
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(acrName) && enableSystemIdentity) {
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951795-a136-40b6-9b6e-7ee7f4fb2b5d') // AcrPull
    principalId: containerApp.identity!.principalId
    principalType: 'ServicePrincipal'
  }
}

// Result: Image pull succeeds ✅
```

### Result Comparison

| Step | Old | New |
|------|-----|-----|
| Container App created | ✅ | ✅ |
| System MI created | ✅ | ✅ |
| Registry config created | ✅ | ✅ |
| RBAC role assigned | ❌ | ✅ |
| Image pull succeeds | ❌ | ✅ |

---

## Backward Compatibility

✅ **The fixed module is 100% backward compatible**:
- `acrName` parameter is **optional** (defaults to empty string)
- If not provided, RBAC assignment is **skipped** (conditional resource)
- Existing public registry deployments work unchanged
- No breaking changes to other parameters

### Safe to Apply Immediately
All existing code using the old module will continue working. New code can use the new features.

---

## Affected Projects

| Project | Template | Status | Action |
|---------|----------|--------|--------|
| **22-rg-sandbox** | container-app.bicep | Original | Keep as-is for reference |
| **22-rg-sandbox** | container-app-rbac-fixed.bicep | New | Use for ALL new deployments |
| **Other projects** using old module | Any | Inherited | Migrate on next update cycle |

---

## Long-term Recommendations

1. **Deprecate Old Module**: Mark `container-app.bicep` as deprecated, point to new version
2. **CI/CD Validation**: Add Bicep lint rule to detect vulnerable patterns
3. **Reusable Module**: Store fixed version in workspace shared modules
4. **Documentation**: Update 18-azure-best with Container Apps + private ACR best practices

---

## Diagnostic Commands

### If Image Pull Still Fails

```powershell
# 1. Verify RBAC role assignment exists
az role assignment list \
  --scope "/subscriptions/YOUR_SUB/resourceGroups/RG/providers/Microsoft.ContainerRegistry/registries/ACRNAME" \
  --query "[?principalType=='ServicePrincipal' && roleDefinitionName=='AcrPull']"

# If empty: Re-run deployment or manually add role assignment

# 2. Verify Container App's managed identity
az containerapp show \
  -n APPNAME \
  -g RG \
  --query identity

# Expected output includes principalId (if system-assigned)

# 3. Check Container App logs
az containerapp logs show \
  -n APPNAME \
  -g RG \
  --container-name APPNAME
```

---

## References

- **Workspace RCA**: `/memories/session/rca-aca-auth-blocker.md`
- **Fixed Template (kernel-engine)**: `19-ai-gov/kernel-engine/deploy/kernel-engine-acr-fixed.bicep`
- **Audit Report**: `/memories/session/audit-aca-acr-pattern-20260314.md`
- **Azure Best Practices**: `18-azure-best/12-security/rbac.md`

---

## Support

For issues using this module:
1. Check diagnostic commands above
2. Verify ACR name and resource group parameters
3. Confirm Container App's managed identity has AcrPull role on ACR
4. Review deployment output: `acrPullRoleAssignmentId` should have a value (not empty)

**Questions or issues**: File GitHub issue with template output and deployment logs.

---

**Module Status**: READY FOR PRODUCTION  
**Tested**: Yes (deployed to kernel-engine  
**Backward Compatible**: Yes  
**Breaking Changes**: None
