# Storage Assessment Report - EsDAICoE-Sandbox

**Assessment Date**: 2026-02-04 15:27:49  
**Subscription**: EsDAICoESub (d2d4e571-e0f2-4f6c-901a-f88f7669bcba)  
**Resource Group**: EsDAICoE-Sandbox  
**Storage Accounts Found**: 6  
**Total Size**:  GB  
**Total Blobs**: 

---

## Executive Summary

**Storage Status**:
- **Empty**:  storage account(s)
- **Contains Data**:  storage account(s)
- **Total Containers**: 

---

## Storage Accounts Detail

###  Storage Account: 

**Configuration**:
- **SKU**:  | **Kind**:  | **Location**: 
- **Created**: 
- **Access Tier**: 
- **Public Blob Access**: 
- **HTTPS Only**: 
- **Min TLS Version**: 

**Network Security**:
- **Default Action**: 
- **Bypass**: 
- **IP Rules**: 
- **VNet Rules**: 

**Storage Summary**:
- **Total Size**:  GB
- **Total Blobs**: 
- **Containers**: 
- **Has Permissions**: 

###  Storage Account: 

**Configuration**:
- **SKU**:  | **Kind**:  | **Location**: 
- **Created**: 
- **Access Tier**: 
- **Public Blob Access**: 
- **HTTPS Only**: 
- **Min TLS Version**: 

**Network Security**:
- **Default Action**: 
- **Bypass**: 
- **IP Rules**: 
- **VNet Rules**: 

**Storage Summary**:
- **Total Size**:  GB
- **Total Blobs**: 
- **Containers**: 
- **Has Permissions**: 

###  Storage Account: 

**Configuration**:
- **SKU**:  | **Kind**:  | **Location**: 
- **Created**: 
- **Access Tier**: 
- **Public Blob Access**: 
- **HTTPS Only**: 
- **Min TLS Version**: 

**Network Security**:
- **Default Action**: 
- **Bypass**: 
- **IP Rules**: 
- **VNet Rules**: 

**Storage Summary**:
- **Total Size**:  GB
- **Total Blobs**: 
- **Containers**: 
- **Has Permissions**: 

###  Storage Account: 

**Configuration**:
- **SKU**:  | **Kind**:  | **Location**: 
- **Created**: 
- **Access Tier**: 
- **Public Blob Access**: 
- **HTTPS Only**: 
- **Min TLS Version**: 

**Network Security**:
- **Default Action**: 
- **Bypass**: 
- **IP Rules**: 
- **VNet Rules**: 

**Storage Summary**:
- **Total Size**:  GB
- **Total Blobs**: 
- **Containers**: 
- **Has Permissions**: 

###  Storage Account: 

**Configuration**:
- **SKU**:  | **Kind**:  | **Location**: 
- **Created**: 
- **Access Tier**: 
- **Public Blob Access**: 
- **HTTPS Only**: 
- **Min TLS Version**: 

**Network Security**:
- **Default Action**: 
- **Bypass**: 
- **IP Rules**: 
- **VNet Rules**: 

**Storage Summary**:
- **Total Size**:  GB
- **Total Blobs**: 
- **Containers**: 
- **Has Permissions**: 

###  Storage Account: 

**Configuration**:
- **SKU**:  | **Kind**:  | **Location**: 
- **Created**: 
- **Access Tier**: 
- **Public Blob Access**: 
- **HTTPS Only**: 
- **Min TLS Version**: 

**Network Security**:
- **Default Action**: 
- **Bypass**: 
- **IP Rules**: 
- **VNet Rules**: 

**Storage Summary**:
- **Total Size**:  GB
- **Total Blobs**: 
- **Containers**: 
- **Has Permissions**: 

---

## Copy Plan Template

### Source Identification

| Source Storage | Source Container | Content Type | Size (GB) | Blob Count |
|----------------|------------------|--------------|-----------|------------|

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
- **JSON Data**: .\assessments\20260204-152629\storage-assessment.json
- **Storage List**: .\assessments\20260204-152629\storage-accounts.json
- **This Report**: .\assessments\20260204-152629\STORAGE-ASSESSMENT-SUMMARY.md
**Log File**: .\assessments\20260204-152629\assessment-log.txt

---

*Assessment completed: 2026-02-04 15:27:50*

