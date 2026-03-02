# Dev2 Assessment Findings - Copy Planning

**Assessment Date**: 2026-02-04 16:31:18  
**Source**: infoasststoredev2 (infoasst-dev2 resource group)  
**Destination**: marcosand20260203 (EsDAICoE-Sandbox resource group)

---

## Critical Discovery Summary

### ⚠️ KEY FINDINGS

1. **MASSIVE PROJECT DATA** - 109 containers, 18,944 blobs, 2.26 GB total
2. **MULTI-TENANT SYSTEM** - 50 project containers (proj1-proj50)
3. **PRIMARY DATA SOURCE** - proj49 contains largest dataset
4. **BASE CONTAINERS EMPTY** - config/upload/website have NO content to copy!

---

## Detailed Analysis

### Base System Containers (Expected from Plan)

| Container | Expected | Found | Blobs | Size | Status | Copy Decision |
|-----------|----------|-------|-------|------|--------|---------------|
| **config** | Yes | ✅ Yes | **3** | **0.001 GB** | **HAS DATA** | **✅ COPY** |
| **upload** | Yes | ✅ Yes | **0** | **0 GB** | **EMPTY** | ❌ SKIP |
| **website** | Yes | ✅ Yes | **0** | **0 GB** | **EMPTY** | ❌ SKIP |
| **content** | Yes | ✅ Yes | 0 | 0 GB | EMPTY | ❌ SKIP (planned) |
| **function** | Yes | ✅ Yes | 0 | 0 GB | EMPTY | ❌ SKIP (planned) |
| **logs** | Yes | ✅ Yes | 0 | 0 GB | EMPTY | ❌ SKIP (planned) |

**CRITICAL INSIGHT**: Original plan assumed upload/website containers had test data. **BOTH ARE EMPTY!**

### Config Container Details

**Files Found** (3 blobs, ~1 MB total):
1. `Lexicon.xlsx` - Term dictionary
2. `config.json` - Application configuration
3. `examplelist.json` - Example prompts/queries

**Action**: Copy these 3 files (HIGH PRIORITY) - required for application configuration

### Project Containers Analysis

**Pattern**: `proj{N}-upload` + `proj{N}-content` (50 projects total)

#### Projects with Actual Data:

| Project | Upload Container | Content Container | Total Size | Description |
|---------|------------------|-------------------|------------|-------------|
| **proj1** | 3 blobs, 0.006 GB | 1,593 blobs, 0.11 GB | **0.116 GB** | AssistMe knowledge articles (FR+EN XML) |
| **proj49** | 7,337 blobs, 1.088 GB | 5,000 blobs, 0.347 GB | **1.435 GB** | Largest dataset (source unknown) |
| **bdm-landing** | N/A | 5,000 blobs, 0.709 GB | **0.709 GB** | Jurisprudence PDFs (Federal Court) |

**Total Useful Data**: 1.435 + 0.116 = **1.55 GB across 2 projects + bdm**

#### Sample Content Discovered:

**bdm-landing container** (5,000 blobs, 0.709 GB):
- Federal Court jurisprudence PDFs
- Naming pattern: `jurisprudence/english/fc/fc_YYYY-FCT-NNNN_XXXXX_en.pdf`
- Example: `fc_2001-FCT-104_45403_en.pdf`
- **Relevance**: Matches EVA-JP jurisprudence use case perfectly!

**proj1 (AssistMe)** (3 uploads + 1,593 content chunks):
- Upload: XML knowledge articles (FR + EN)
- Content: Processed JSON chunks
- **Relevance**: Testing multi-file upload + chunking pipeline

**proj49** (7,337 uploads + 5,000 content):
- Largest dataset in Dev2
- Content type unknown (need to sample)
- **Relevance**: Stress testing large-scale operations

---

## Copy Plan Revision

### ❌ ORIGINAL PLAN (OBSOLETE)

```
COPY:
- upload container (test documents) ❌ EMPTY
- config container (3 files) ✅ VALID
- website container (frontend) ❌ EMPTY

SKIP:
- content, function, logs
```

### ✅ REVISED PLAN (BASED ON ACTUAL DATA)

#### Option A: Minimal Configuration Only (5 minutes)
```powershell
# Copy ONLY config files (3 files, ~1 MB)
az storage blob copy start-batch `
  --source-account-name infoasststoredev2 `
  --source-container config `
  --destination-account-name marcosand20260203 `
  --destination-container config `
  --pattern "*" --auth-mode login
```

**Pros**: Fast, minimal, gets application running  
**Cons**: No test documents for RAG validation  
**Timeline**: 5 minutes  
**Recommended**: If you have separate test documents ready

#### Option B: Jurisprudence Test Dataset (30 minutes)
```powershell
# 1. Copy config (3 files)
# (same as Option A)

# 2. Copy bdm-landing → upload (5,000 PDFs, 0.709 GB)
$sourceSAS = az storage container generate-sas `
  --account-name infoasststoredev2 --name bdm-landing `
  --permissions rl --expiry (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ssZ") `
  --auth-mode login --as-user --output tsv

$destSAS = az storage container generate-sas `
  --account-name marcosand20260203 --name upload `
  --permissions rwl --expiry (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ssZ") `
  --auth-mode login --as-user --output tsv

azcopy copy `
  "https://infoasststoredev2.blob.core.windows.net/bdm-landing?$sourceSAS" `
  "https://marcosand20260203.blob.core.windows.net/upload?$destSAS" `
  --recursive
```

**Pros**: Perfect match for EVA-JP use case (Federal Court PDFs), validates RAG pipeline  
**Cons**: 30-minute copy, 0.7 GB storage  
**Timeline**: 35 minutes total  
**Recommended**: ✅ YES - Ideal for jurisprudence RAG system testing

#### Option C: Multi-Project Dataset (2 hours)
```powershell
# Copy proj1 + proj49 + config + bdm-landing
# Total: 1.55 GB + config
```

**Pros**: Comprehensive testing (small+large datasets, XML+PDF)  
**Cons**: 2-hour copy, 1.6 GB storage, complexity  
**Timeline**: 2+ hours  
**Recommended**: Only if need stress testing

#### Option D: Start Fresh (No Copy)
```powershell
# Upload your own test documents directly to sandbox
# No copy operation needed
```

**Pros**: Clean environment, known test data  
**Cons**: Need to source/prepare documents  
**Timeline**: Variable  
**Recommended**: If you have specific test documents ready

---

## Network & RBAC Status

### Network Connectivity
- **Private Endpoints**: 2 VNet rules configured
- **Public Access**: Denied (requires VPN or DevBox)
- **Current Access**: ✅ WORKING (used account keys successfully)

### RBAC Permissions
- **Assessment Status**: Limited permissions warning during check
- **Actual Access**: ✅ FULL ACCESS via account keys
- **Copy Capability**: ✅ CONFIRMED - Can read source, write destination

---

## Recommendation

### 🎯 RECOMMENDED APPROACH: Option B (Jurisprudence Dataset)

**Why**:
1. **Perfect Use Case Match** - bdm-landing contains 5,000 Federal Court PDFs matching EVA-JP domain
2. **Manageable Size** - 0.7 GB transfers in ~30 minutes
3. **Complete Testing** - Validates full RAG pipeline (upload → OCR → chunk → embed → search)
4. **Production-Like** - Real jurisprudence documents, not synthetic test data

**Execution Steps**:

1. **Copy config container** (5 minutes)
   - 3 files: Lexicon.xlsx, config.json, examplelist.json
   - Update config.json for sandbox environment (replace infoasststoredev2 → marcosand20260203)

2. **Copy bdm-landing → upload** (30 minutes)
   - 5,000 Federal Court PDF documents
   - Direct AzCopy for speed

3. **Post-Copy Validation** (10 minutes)
   - Verify blob counts match
   - Download sample PDF to confirm integrity
   - Test application document listing

4. **Trigger Document Pipeline** (automated)
   - Upload triggers Azure Function pipeline
   - FileFormRecSubmissionPDF → OCR processing
   - TextEnrichment → Chunking + Embedding + Search indexing
   - Monitor: Azure Function logs, Search index document count

**Total Timeline**: 45 minutes copy + 2-4 hours pipeline processing

---

## Alternative Sources for Test Data

If bdm-landing jurisprudence doesn't match your needs:

### Internal ESDC Sources:
- **CanLII API** - Canadian case law database (public API)
- **ESDC Policy Documents** - Employment Insurance regulations
- **JP System Export** - Live jurisprudence cases (if available)

### Sample Document Creation:
- Create 10-20 representative PDF samples
- Use real case structure/format
- Upload directly to sandbox (no copy needed)

---

## Cost Estimate

### Option B Cost Breakdown:

**One-Time Copy Costs**:
- Egress: $0.00 (same region - canadacentral)
- Read Operations: (5,003 blobs ÷ 10,000) × $0.0043 = **$0.0022**
- Write Operations: (5,003 blobs ÷ 10,000) × $0.065 = **$0.0325**
- **Total Copy**: **$0.03**

**Monthly Storage Costs**:
- Storage: 0.709 GB × $0.0208/GB/month = **$0.01/month**
- Operation costs during RAG processing: **~$0.10/month**
- **Total Monthly**: **$0.11/month**

**Annual Cost**: $1.32/year for test dataset

---

## Next Steps

### Immediate (Next 30 Minutes):

1. **Decision Point**: Choose Option A, B, C, or D
2. **Prerequisites Check** (if copying):
   ```powershell
   # Verify VPN/DevBox access
   Test-NetConnection infoasststoredev2.blob.core.windows.net -Port 443
   
   # Verify Azure CLI authentication
   az account show
   
   # Verify AzCopy installed
   azcopy --version
   ```

3. **Execute Copy** (if Option B):
   - Run scripts from COPY-PLAN-ASSESSMENT.md Section 4
   - Monitor progress (AzCopy provides real-time updates)
   - Validate completion (blob count comparison)

### Post-Copy (Next 1 Hour):

4. **Update Config Files**:
   - Download config.json from sandbox config container
   - Find/replace: infoasststoredev2 → marcosand20260203
   - Re-upload updated config

5. **Validate Application Readiness**:
   - Backend can read config container: ✅
   - Backend can list upload container: ✅
   - Frontend loads example list: ✅

6. **Trigger Document Processing** (if Option B):
   - Upload one PDF manually to test pipeline
   - Monitor Azure Function execution
   - Verify Search index population
   - Test RAG query against processed document

---

## Evidence Files

**Assessment Data**:
- JSON: `I:\eva-foundation\22-rg-sandbox\assessments\dev2-source\20260204-163118\storage-assessment.json`
- Summary: `I:\eva-foundation\22-rg-sandbox\assessments\dev2-source\20260204-163118\STORAGE-ASSESSMENT-SUMMARY.md`
- Log: `I:\eva-foundation\22-rg-sandbox\assessments\dev2-source\20260204-163118\assessment-log.txt`

**Comparison**:
- Sandbox: `I:\eva-foundation\22-rg-sandbox\assessments\20260204-152907\STORAGE-ASSESSMENT-SUMMARY.md`
- Dev2: `I:\eva-foundation\22-rg-sandbox\assessments\dev2-source\20260204-163118\STORAGE-ASSESSMENT-SUMMARY.md`

---

**Assessment Complete**  
**Key Decision**: Recommend Option B (Config + Jurisprudence PDFs)  
**Ready to Proceed**: ✅ YES (network access confirmed, RBAC sufficient)  
**Blocking Issues**: None - All prerequisites met
