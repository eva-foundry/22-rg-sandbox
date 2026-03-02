# Storage Assessment Report - EsDAICoE-Sandbox

**Assessment Date**: 2026-02-04 15:30:43  
**Subscription**: EsDAICoESub (d2d4e571-e0f2-4f6c-901a-f88f7669bcba)  
**Resource Group**: EsDAICoE-Sandbox  
**Storage Accounts Found**: 6  
**Total Size**: 0.01 GB  
**Total Blobs**: 7

---

## Executive Summary

**Storage Status**:
- **Empty**: 1 storage account(s)
- **Contains Data**: 5 storage account(s)
- **Total Containers**: 15

**Errors Encountered**: 1

---

## Storage Accounts Detail

### [EMPTY] Storage Account: esdaicoesandboxst

**Configuration**:
- **SKU**: Standard_LRS | **Kind**: StorageV2 | **Location**: canadaeast
- **Created**: 04/17/2025 15:10:50
- **Access Tier**: Hot
- **Public Blob Access**: False
- **HTTPS Only**: True
- **Min TLS Version**: TLS1_2

**Network Security**:
- **Default Action**: Deny
- **Bypass**: AzureServices
- **IP Rules**: 1
- **VNet Rules**: 0

**Storage Summary**:
- **Total Size**: 0 GB
- **Total Blobs**: 0
- **Containers**: 0
- **Has Permissions**: True

**Errors**:
- Storage account assessment failed: Command failed with exit code 1


### [DATA] Storage Account: eqvispocaistorage

**Configuration**:
- **SKU**: Standard_LRS | **Kind**: StorageV2 | **Location**: canadacentral
- **Created**: 04/29/2025 14:55:09
- **Access Tier**: Hot
- **Public Blob Access**: False
- **HTTPS Only**: True
- **Min TLS Version**: TLS1_2

**Network Security**:
- **Default Action**: Deny
- **Bypass**: AzureServices
- **IP Rules**: 1
- **VNet Rules**: 0

**Storage Summary**:
- **Total Size**: 0 GB
- **Total Blobs**: 0
- **Containers**: 2
- **Has Permissions**: True

**Container Breakdown**:

| Container | Blobs | Size (GB) | Public Access | Last Modified |
|-----------|-------|-----------|---------------|---------------|
| 0f471f3c-32de-4d74-8684-79f3a9a2469f-azureml | 0 | 0 | None | 02/04/2026 10:49:01 |
| 0f471f3c-32de-4d74-8684-79f3a9a2469f-azureml-blobstore | 0 | 0 | None | 02/04/2026 10:49:01 |


### [DATA] Storage Account: eqvispocdata

**Configuration**:
- **SKU**: Standard_LRS | **Kind**: StorageV2 | **Location**: canadacentral
- **Created**: 04/29/2025 11:38:18
- **Access Tier**: Hot
- **Public Blob Access**: False
- **HTTPS Only**: True
- **Min TLS Version**: TLS1_2

**Network Security**:
- **Default Action**: Deny
- **Bypass**: AzureServices
- **IP Rules**: 1
- **VNet Rules**: 0

**Storage Summary**:
- **Total Size**: 0.008 GB
- **Total Blobs**: 5
- **Containers**: 4
- **Has Permissions**: True

**Container Breakdown**:

| Container | Blobs | Size (GB) | Public Access | Last Modified |
|-----------|-------|-----------|---------------|---------------|
| fileupload-navigation | 1 | 0 | None | 05/01/2025 15:37:16 |
| fileupload-viz1 | 2 | 0.006 | None | 10/21/2025 14:57:56 |
| fileupload-viz3 | 1 | 0.001 | None | 10/21/2025 15:17:36 |
| fileupload-vizshort | 1 | 0.001 | None | 10/21/2025 15:13:20 |


**Sample Blobs in fileupload-viz1**:
- `really_short.txt`
- `short.txt`


### [DATA] Storage Account: eqvispocfuncstorage

**Configuration**:
- **SKU**: Standard_LRS | **Kind**: StorageV2 | **Location**: canadacentral
- **Created**: 04/29/2025 10:55:45
- **Access Tier**: Hot
- **Public Blob Access**: False
- **HTTPS Only**: True
- **Min TLS Version**: TLS1_2

**Network Security**:
- **Default Action**: Deny
- **Bypass**: AzureServices
- **IP Rules**: 1
- **VNet Rules**: 0

**Storage Summary**:
- **Total Size**: 0 GB
- **Total Blobs**: 2
- **Containers**: 2
- **Has Permissions**: True

**Container Breakdown**:

| Container | Blobs | Size (GB) | Public Access | Last Modified |
|-----------|-------|-----------|---------------|---------------|
| azure-webjobs-hosts | 1 | 0 | None | 04/29/2025 11:25:31 |
| azure-webjobs-secrets | 1 | 0 | None | 04/29/2025 11:25:56 |


### [DATA] Storage Account: marcosand20260203

**Configuration**:
- **SKU**: Standard_LRS | **Kind**: StorageV2 | **Location**: canadacentral
- **Created**: 02/03/2026 12:18:53
- **Access Tier**: Hot
- **Public Blob Access**: False
- **HTTPS Only**: True
- **Min TLS Version**: TLS1_2

**Network Security**:
- **Default Action**: Deny
- **Bypass**: AzureServices
- **IP Rules**: 1
- **VNet Rules**: 0

**Storage Summary**:
- **Total Size**: 0 GB
- **Total Blobs**: 0
- **Containers**: 6
- **Has Permissions**: True

**Container Breakdown**:

| Container | Blobs | Size (GB) | Public Access | Last Modified |
|-----------|-------|-----------|---------------|---------------|
| config | 0 | 0 | None | 02/04/2026 11:31:38 |
| content | 0 | 0 | None | 02/04/2026 11:31:35 |
| function | 0 | 0 | None | 02/04/2026 11:31:44 |
| logs | 0 | 0 | None | 02/04/2026 11:31:41 |
| upload | 0 | 0 | None | 02/04/2026 11:31:32 |
| website | 0 | 0 | None | 02/04/2026 11:31:47 |


### [DATA] Storage Account: marcosandboxfinopshub

**Configuration**:
- **SKU**: Standard_LRS | **Kind**: StorageV2 | **Location**: canadacentral
- **Created**: 02/03/2026 17:33:30
- **Access Tier**: Hot
- **Public Blob Access**: False
- **HTTPS Only**: True
- **Min TLS Version**: TLS1_2

**Network Security**:
- **Default Action**: Deny
- **Bypass**: AzureServices
- **IP Rules**: 1
- **VNet Rules**: 0

**Storage Summary**:
- **Total Size**: 0 GB
- **Total Blobs**: 0
- **Containers**: 1
- **Has Permissions**: True

**Container Breakdown**:

| Container | Blobs | Size (GB) | Public Access | Last Modified |
|-----------|-------|-----------|---------------|---------------|
| costs | 0 | 0 | None | 02/03/2026 17:49:31 |


---

## Copy Plan Template

### Source Identification

| Source Storage | Source Container | Content Type | Size (GB) | Blob Count |
|----------------|------------------|--------------|-----------|------------|
| eqvispocaistorage | 0f471f3c-32de-4d74-8684-79f3a9a2469f-azureml | [TO FILL] | 0 | 0 |
| eqvispocaistorage | 0f471f3c-32de-4d74-8684-79f3a9a2469f-azureml-blobstore | [TO FILL] | 0 | 0 |
| eqvispocdata | fileupload-navigation | [TO FILL] | 0 | 1 |
| eqvispocdata | fileupload-viz1 | [TO FILL] | 0.006 | 2 |
| eqvispocdata | fileupload-viz3 | [TO FILL] | 0.001 | 1 |
| eqvispocdata | fileupload-vizshort | [TO FILL] | 0.001 | 1 |
| eqvispocfuncstorage | azure-webjobs-hosts | [TO FILL] | 0 | 1 |
| eqvispocfuncstorage | azure-webjobs-secrets | [TO FILL] | 0 | 1 |
| marcosand20260203 | config | [TO FILL] | 0 | 0 |
| marcosand20260203 | content | [TO FILL] | 0 | 0 |
| marcosand20260203 | function | [TO FILL] | 0 | 0 |
| marcosand20260203 | logs | [TO FILL] | 0 | 0 |
| marcosand20260203 | upload | [TO FILL] | 0 | 0 |
| marcosand20260203 | website | [TO FILL] | 0 | 0 |
| marcosandboxfinopshub | costs | [TO FILL] | 0 | 0 |

### Destination Mapping

| From (Source) | To (Destination) | Container | Priority | Notes |
|---------------|------------------|-----------|----------|-------|
| [SOURCE_STORAGE] | marcosand20260203 | [CONTAINER] | High | [PURPOSE] |

### Copy Method Recommendations

**For containers < 1 GB**:
```powershell
# Use az storage blob copy
az storage blob copy start-batch \
  --source-account-name [SOURCE] \
  --source-container [CONTAINER] \
  --destination-account-name marcosand20260203 \
  --destination-container [CONTAINER] \
  --pattern "*"
```

**For containers > 1 GB**:
```powershell
# Use AzCopy for better performance
azcopy copy \
  "https://[SOURCE].blob.core.windows.net/[CONTAINER]?[SAS_TOKEN]" \
  "https://marcosand20260203.blob.core.windows.net/[CONTAINER]?[SAS_TOKEN]" \
  --recursive
```

---

## Next Steps

**Immediate Actions**:
1. [ ] Review this assessment report
2. [ ] Identify content sources (Dev2, external, sample data?)
3. [ ] Fill out the Copy Plan Template above
4. [ ] Verify access permissions on source and destination
5. [ ] Test copy with small sample before bulk copy
6. [ ] Execute copy operations (use generated script if available)
7. [ ] Validate copied content

**Prerequisites Before Copy**:
- [ ] Source storage account identified
- [ ] Access keys or SAS tokens obtained
- [ ] Network connectivity verified (private endpoints, firewalls)
- [ ] Destination containers created
- [ ] RBAC permissions validated (Storage Blob Data Contributor)
- [ ] Estimated copy time calculated
- [ ] Backup plan defined (if overwriting existing data)

---

**Assessment Files**:
- **JSON Data**: .\assessments\20260204-152907\storage-assessment.json
- **Storage List**: .\assessments\20260204-152907\storage-accounts.json
- **This Report**: .\assessments\20260204-152907\STORAGE-ASSESSMENT-SUMMARY.md
**Log File**: .\assessments\20260204-152907\assessment-log.txt

---

*Assessment completed: 2026-02-04 15:30:43*

