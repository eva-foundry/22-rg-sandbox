# Seeding the Sandbox Process

**Project**: EVA-JP Self-Service Sandbox  
**Goal**: One-click developer sandbox with working instance  
**Date**: February 5, 2026  
**Context**: Part of `I:\eva-foundation\22-rg-sandbox` - Automated EVA-JP environment provisioning  
**Script Location**: `I:\EVA-JP-v1.2\populate-marco-sandbox-complete.py` (1,210 lines, production-ready)

---

## 🚨 CRITICAL: Environment Configuration Issues

**Status**: 🔴 Blocking development - 3-day configuration struggle identified  
**Root Cause**: Mixed environment services + inconsistent variable loading

**Quick Fix** (15 minutes):  
→ See `I:\EVA-JP-v1.2\ENVIRONMENT-FIX-QUICKSTART.md`

**Full Assessment** (complete analysis + long-term fixes):  
→ See `I:\EVA-JP-v1.2\docs\ENVIRONMENT-CONFIG-ASSESSMENT.md`

**Key Issues**:
1. `.env` file using HCCLD2 services but showing "Marco Sandbox" branding
2. `enrichment.env` file missing (only `.example` exists)
3. Inconsistent environment variable loading order across modules
4. No validation of service endpoint consistency

**Environment Comparison Table**: See section below ⬇️

---

## EVA-JP Multi-Environment Configuration Matrix

**Complete Reference**: All three EVA-JP environments and their Azure services

### Environment Summary

| Environment | **MARCO-SANDBOX** | **DEV2** | **HCCLD2** |
|-------------|-------------------|----------|------------|
| **Type** | Personal sandbox | Shared development | Production secure |
| **Resource Group** | `EsDAICoE-Sandbox` | `infoasst-dev2` | `infoasst-hccld2` |
| **Subscription** | EsDAICoESub (d2d4e571...) | EsDAICoESub (d2d4e571...) | EsDAICoESub (d2d4e571...) |
| **Access** | Public | Mixed | Private endpoints (VPN) |
| **Status** | 100% self-sufficient | Shared resource | Production |

### Azure Service Endpoints

| Service | **MARCO-SANDBOX** | **DEV2** | **HCCLD2** |
|---------|-------------------|----------|------------|
| **Cosmos DB** | `marco-sandbox-cosmos` | `infoasst-cosmos-dev2` | `infoasst-cosmos-hccld2` |
| **Storage** | `marcosand20260203` | `infoasststoredev2` | `infoasststorehccld2` |
| **Queue** | `marcosand20260203` | `infoasststoredev2` | `infoasststorehccld2` |
| **Search** | `marco-sandbox-search` | `infoasst-search-dev2` | `infoasst-search-hccld2` |
| **OpenAI** | `marco-sandbox-openai` ⚠️ | `infoasst-aoai-dev2` | `infoasst-aoai-hccld2` |
| **AI Services** | `marco-sandbox-aisvc` | `infoasst-aisvc-dev2` | `infoasst-aisvc-hccld2` |
| **Document Intel** | `marco-sandbox-docint` | `infoasst-docint-dev2` | `infoasst-docint-hccld2` |
| **Enrichment** | `marco-sandbox-enrichment` | `infoasst-enrichmentweb-dev2` | `infoasst-enrichmentweb-hccld2` |

⚠️ `marco-sandbox-openai` is temporary personal resource - should migrate to MarcoSub subscription

### Model Configuration

| Setting | **MARCO-SANDBOX** | **DEV2** | **HCCLD2** |
|---------|-------------------|----------|------------|
| **Chat Model** | `gpt-4o` | `gpt-4o` | `gpt-4.1-mini` |
| **Model Version** | 2024-11-20 | 2024-08-06 | 2024-12-01-preview |
| **Embeddings** | `text-embedding-ada-002` | `text-embedding-3-small` | `text-embedding-3-small` |
| **Vector Size** | 1536 | 3072 | 3072 |

### UI Configuration

| Setting | **MARCO-SANDBOX** | **DEV2** | **HCCLD2** |
|---------|-------------------|----------|------------|
| **Title** | `[MARCO-SANDBOX]` | `[DEV2]` | `[HCCLD2]` |
| **Warning Banner** | `Marco Sandbox - 100% Self-Sufficient` | `Dev2 Development - Shared` | `HCCLD2 Production - VPN Required` |
| **Log Level** | `INFO` | `INFO` | `WARNING` |

### Feature Flags

| Flag | **MARCO** | **DEV2** | **HCCLD2** | **Purpose** |
|------|-----------|----------|------------|-------------|
| `ENABLE_MATH_ASSISTANT` | `true` | `true` | `false` | Math calculations |
| `ENABLE_TABULAR_DATA` | `true` | `true` | `false` | CSV analysis |
| `OPTIMIZED_KEYWORD_SEARCH_OPTIONAL` | `true` | `true` | `true` | AI Services fallback |
| `ENRICHMENT_OPTIONAL` | `true` | `true` | `true` | Embedding fallback |

**Detailed Configuration**: See `I:\EVA-JP-v1.2\docs\ENVIRONMENT-CONFIG-ASSESSMENT.md`

---

## Problem Statement

Developers need a **working EVA-JP instance** for testing, not just infrastructure. Current deployment creates empty Azure resources but requires manual data population before the application is usable.

### Current State (After Infrastructure Deployment)
- ✅ Azure resources provisioned (Cosmos DB, Storage, Search, OpenAI)
- ✅ Backend and frontend deployed
- ❌ **Empty databases** - No RBAC groups, no example questions
- ❌ **Empty blob storage** - No containers created
- ❌ **Empty search index** - No sample documents processed
- ❌ **No conversation history** - Nothing to demonstrate

**Result**: App starts but returns errors or "no data found" on every action.

### Desired State (After Seeding)
- ✅ All infrastructure
- ✅ **RBAC groups configured** - 3 roles (Admin, Contributor, Reader)
- ✅ **Example questions loaded** - UI displays suggestion prompts
- ✅ **Blob containers created** - Upload pipeline ready
- ✅ **Sample document indexed** - At least one Q&A works
- ✅ **Conversation history** - Shows app in "already used" state

**Result**: Developer can log in, see suggestions, ask questions, get answers - immediately.

---

## Data Dependency Chain

Understanding the complete flow is critical for seeding correctly:

### 1. Infrastructure Layer (Required First)

```
Azure Resources
├─> Cosmos DB (4 databases)
│   ├─> groupsToResourcesMap
│   ├─> UserInformation
│   ├─> conversations
│   └─> statusdb
├─> Blob Storage
│   ├─> upload (staging)
│   └─> documents (processed)
├─> Azure Search
│   └─> vector-index (hybrid search)
└─> Azure Functions
    ├─> FileUploadedEtrigger
    ├─> FileFormRecSubmissionPDF
    └─> TextEnrichment
```

### 2. Seed Data Layer (Minimal for App Start)

**Priority 1: RBAC & Authorization**
```
groupsToResourcesMap/groupResourcesMapContainer
├─> Admin Group (9f540c2e-e05c-4012-ba43-4846dabfaea6)
│   └─> Permissions: Storage Contributor, Search Contributor
├─> Contributor Group (3fece663-68ea-4a30-b76d-f745be3b62db)
│   └─> Permissions: Storage Contributor, Search Reader
└─> Reader Group (9b0ab3c1-9863-4aab-a4ae-3a49c63b03b4)
    └─> Permissions: Storage Reader, Search Reader
```

**Priority 2: UI Prompts**
```
UserInformation/group_management
├─> Admin Examples (3 questions)
├─> Contributor Examples (3 questions)
└─> Reader Examples (3 questions)
```

**Priority 3: Storage Containers**
```
Blob Storage
├─> upload/ (for new uploads)
└─> documents/ (for processed files)
```

### 3. Data Ingestion Flow (For Working Demo)

```
1. Upload Sample Document
   └─> Blob: upload/sample.pdf

2. Azure Functions Pipeline
   └─> FileUploadedEtrigger (blob trigger)
       └─> Detects new file
           └─> FileFormRecSubmissionPDF (Document Intelligence)
               └─> OCR extraction (text, layout, tables)
                   └─> TextEnrichment
                       └─> Chunking (512 tokens)
                       └─> Embeddings (text-embedding-ada-002)
                       └─> Output:
                           ├─> documents/sample_chunk_001.json
                           ├─> documents/sample_chunk_002.json
                           └─> Search Index entries (with vectors)
```

### 4. RAG Query Flow (Answer Questions)

```
User asks: "What are the requirements?"
├─> Backend: /chat endpoint
└─> chatreadretrieveread.py
    ├─> Query optimization (AI Services - optional)
    ├─> Generate question embedding (OpenAI)
    ├─> Hybrid search (vector + keyword)
    │   └─> Returns top 5 chunks with scores
    ├─> Assemble context from chunks
    ├─> Build prompt: system + context + question
    ├─> OpenAI completion (gpt-4o)
    └─> Stream response with citations
```

### 5. Conversation Persistence

```
Chat exchange completed
└─> Save to: conversations/chat_history_session
    {
      "id": "conv-123",
      "userId": "9f540c2e...",
      "conversation_id": "conv-123",
      "messages": [
        {"role": "user", "content": "...", "timestamp": "..."},
        {"role": "assistant", "content": "...", "data_points": [...]}
      ]
    }
```

---

## Populate Script Architecture

**File**: `populate-marco-sandbox-complete.py`  
**Location**: `I:\EVA-JP-v1.2\`  
**Lines**: 1,210

### Professional Components Implemented

**1. DebugArtifactCollector** (Lines 115-165)
- Captures HTML, screenshots, network traces
- Evidence collection at operation boundaries

**2. SessionManager** (Implicit in backup system)
- Checkpoint/resume capabilities
- Rollback from backup files

**3. StructuredErrorHandler** (Lines 285-312)
- JSON error logging with context
- Traceback preservation

**4. Pre-Flight Validation** (Lines 314-522)
- 8-stage validation before execution
- Package checks → Imports → Credentials → Connectivity → Resources

### Script Structure

```python
# Lines 115-165: Conditional imports (prevent import failures)
CosmosClient = None
BlobServiceClient = None
DefaultAzureCredential = None

def import_azure_packages():
    """Load Azure SDKs only if available"""
    # Imports with try/except

# Lines 167-224: Data templates
MOCK_ADMIN_GROUP = "9f540c2e-e05c-4012-ba43-4846dabfaea6"
MOCK_CONTRIBUTOR_GROUP = "3fece663-68ea-4a30-b76d-f745be3b62db"
MOCK_READER_GROUP = "9b0ab3c1-9863-4aab-a4ae-3a49c63b03b4"
PROJECT_NAME = "Local Development"

EXAMPLE_QUESTIONS = {
    "Admin": [...],
    "Contributor": [...],
    "Reader": [...]
}

# Lines 247-312: PopulateScript class
class PopulateScript:
    def __init__(self, dry_run, force):
        # Initialize logging, evidence, session
        
    def validate_prerequisites(self):
        # 8-stage pre-flight validation
        
    def create_group_mapping(self, group_id, group_name, role_type):
        # Generate RBAC structure
        
    def create_example_questions(self, group_id, role_type):
        # Generate example questions
        
    def populate_cosmos_db(self):
        # Create 3 RBAC groups + 3 question sets
        
    def populate_blob_storage(self):
        # Create documents and upload containers
        
    def verify_population(self):
        # Post-execution verification
        
    def save_backup(self):
        # Backup for rollback
        
    def rollback_from_backup(self, backup_file):
        # Undo population
```

---

## Data Templates

### RBAC Group Mapping Template

**Function**: `create_group_mapping()` (Lines 670-718)

**Admin Group** (Full Access):
```json
{
  "id": "9f540c2e-e05c-4012-ba43-4846dabfaea6",
  "group_id": "9f540c2e-e05c-4012-ba43-4846dabfaea6",
  "group_name": "Local Development - Admin",
  "upload_storage": {
    "upload_container": "documents",
    "role": "Storage Blob Data Contributor"
  },
  "blob_access": {
    "blob_container": "documents",
    "role_blob": "Storage Blob Data Contributor"
  },
  "vector_index_access": {
    "index": "vector-index",
    "role_index": "Search Index Data Contributor"
  }
}
```

**Contributor Group** (Limited Write):
```json
{
  "id": "3fece663-68ea-4a30-b76d-f745be3b62db",
  "group_id": "3fece663-68ea-4a30-b76d-f745be3b62db",
  "group_name": "Local Development - Contributor",
  "upload_storage": {
    "upload_container": "documents",
    "role": "Storage Blob Data Contributor"
  },
  "blob_access": {
    "blob_container": "documents",
    "role_blob": "Storage Blob Data Reader"
  },
  "vector_index_access": {
    "index": "vector-index",
    "role_index": "Search Index Data Reader"
  }
}
```

**Reader Group** (Read-Only):
```json
{
  "id": "9b0ab3c1-9863-4aab-a4ae-3a49c63b03b4",
  "group_id": "9b0ab3c1-9863-4aab-a4ae-3a49c63b03b4",
  "group_name": "Local Development - Reader",
  "upload_storage": {
    "upload_container": "documents",
    "role": "Storage Blob Data Reader"
  },
  "blob_access": {
    "blob_container": "documents",
    "role_blob": "Storage Blob Data Reader"
  },
  "vector_index_access": {
    "index": "vector-index",
    "role_index": "Search Index Data Reader"
  }
}
```

### Example Questions Template

**Function**: `create_example_questions()` (Lines 720-730)

**Admin Questions**:
```json
{
  "id": "9f540c2e-e05c-4012-ba43-4846dabfaea6",
  "title": "Chat with your virtual assistant",
  "examples": [
    {
      "text": "Admin Example 1",
      "value": "How do I upload documents to the system?"
    },
    {
      "text": "Admin Example 2",
      "value": "What are the system configuration options?"
    },
    {
      "text": "Admin Example 3",
      "value": "How do I manage user access and permissions?"
    }
  ]
}
```

**Contributor Questions**:
```json
{
  "id": "3fece663-68ea-4a30-b76d-f745be3b62db",
  "title": "Chat with your virtual assistant",
  "examples": [
    {
      "text": "Contributor Example 1",
      "value": "How do I search for specific information in documents?"
    },
    {
      "text": "Contributor Example 2",
      "value": "What file formats are supported for upload?"
    },
    {
      "text": "Contributor Example 3",
      "value": "How do I organize and tag documents?"
    }
  ]
}
```

**Reader Questions**:
```json
{
  "id": "9b0ab3c1-9863-4aab-a4ae-3a49c63b03b4",
  "title": "Chat with your virtual assistant",
  "examples": [
    {
      "text": "Reader Example 1",
      "value": "How do I search the document collection?"
    },
    {
      "text": "Reader Example 2",
      "value": "What information can I access?"
    },
    {
      "text": "Reader Example 3",
      "value": "How do I view document details?"
    }
  ]
}
```

---

## Pre-Flight Validation (8 Stages)

**Function**: `validate_prerequisites()` (Lines 314-522)

### Stage 1: Python Packages
```python
required_packages = [
    'azure.cosmos',
    'azure.storage.blob',
    'azure.identity',
    'azure.core'
]
```
- Validates packages installed BEFORE importing
- Prevents import failures from blocking script

### Stage 2: Azure SDK Import
```python
import_azure_packages()
```
- Conditional imports with error handling
- Sets global variables for use throughout script

### Stage 3: Azure Credentials
```python
self.credential = DefaultAzureCredential()
token = self.credential.get_token("https://management.azure.com/.default")
```
- Tests authentication
- Tries Azure CLI credential first

### Stage 4: Configuration Completeness
```python
required_config = [
    'cosmos_url', 'cosmos_account',
    'storage_account', 'storage_endpoint',
    'search_service', 'search_index'
]
```
- Reads from `backend.env`
- Validates all required keys present

### Stage 5: Cosmos DB Connectivity
```python
client = CosmosClient(cosmos_url, credential=credential)
databases = list(client.list_databases())
```
- Tests actual connection
- Counts databases available

### Stage 6: Blob Storage Connectivity
```python
blob_client = BlobServiceClient(storage_endpoint, credential=credential)
containers = list(blob_client.list_containers())
```
- Tests storage access
- Lists existing containers

### Stage 7: Database Validation
```python
required_dbs = [
    'groupsToResourcesMap',
    'UserInformation',
    'conversations',
    'statusdb'
]
```
- Verifies each database exists
- Fails if infrastructure incomplete

### Stage 8: Container Validation
```python
container_checks = [
    ('groupsToResourcesMap', 'groupResourcesMapContainer'),
    ('UserInformation', 'group_management'),
    ('conversations', 'chat_history_session'),
    ('statusdb', 'statuscontainer')
]
```
- Verifies each container exists
- Tests read access

---

## Safety Features

### 1. Dry-Run Mode
```bash
python populate-marco-sandbox-complete.py --dry-run
```
- Shows what WOULD be created
- No actual writes to Azure
- Validates templates and logic

### 2. Preview Mode
```bash
python populate-marco-sandbox-complete.py --preview
```
- Shows current state of sandbox
- Lists existing items in each container
- Identifies what's missing

### 3. Validate-Only Mode
```bash
python populate-marco-sandbox-complete.py --validate-only
```
- Runs all 8 pre-flight checks
- Reports PASS/FAIL/SKIP for each
- No population executed

### 4. Rollback Capability
```bash
python populate-marco-sandbox-complete.py --rollback populate-backup-20260205_073308.json
```
- Reads backup file created during population
- Deletes all items that were created
- Restores to pre-population state

### 5. Evidence Collection
**Automatic Logging**:
- `logs/populate/populate_TIMESTAMP.log` - Full execution log
- `evidence/populate/populate_evidence_TIMESTAMP.json` - Structured evidence
- `populate-backup-TIMESTAMP.json` - Rollback data

### 6. Force Mode
```bash
python populate-marco-sandbox-complete.py --force
```
- Skips confirmation prompts
- Useful for CI/CD automation
- Still runs all validations

---

## Execution Flow

### Standard Execution
```bash
cd I:\EVA-JP-v1.2
python populate-marco-sandbox-complete.py
```

**Output**:
```
======================================================================
  MARCO-SANDBOX POPULATE SCRIPT INITIALIZED
======================================================================
Dry Run: False
Force Mode: False
Log File: logs\populate\populate_20260205_073308.log
Evidence File: evidence\populate\populate_evidence_20260205_073308.json

======================================================================
  CONFIGURATION
======================================================================

Cosmos DB: marco-sandbox-cosmos
  - groupsToResourcesMap/groupResourcesMapContainer
  - UserInformation/group_management
  - conversations/chat_history_session
  - statusdb/statuscontainer

Blob Storage: marcosand20260203
  - documents
  - upload

Search Service: marco-sandbox-search
  - vector-index

======================================================================
  PRE-FLIGHT VALIDATION
======================================================================

1. Checking required Python packages...
   [PASS] azure.cosmos
   [PASS] azure.storage.blob
   [PASS] azure.identity
   [PASS] azure.core

2. Importing Azure SDK packages...
   [PASS] Azure SDK packages imported successfully

3. Checking Azure credentials...
   [PASS] DefaultAzureCredential authenticated

4. Checking configuration completeness...
   [PASS] cosmos_url: https://marco-sandbox-cosmos.documents.azure.com:443/
   [PASS] cosmos_account: marco-sandbox-cosmos
   [PASS] storage_account: marcosand20260203
   [PASS] storage_endpoint: https://marcosand20260203.blob.core.windows.net/
   [PASS] search_service: marco-sandbox-search
   [PASS] search_index: vector-index

5. Testing Cosmos DB connectivity...
   [PASS] Connected to Cosmos DB (4 databases found)

6. Testing Blob Storage connectivity...
   [PASS] Connected to Blob Storage (6 containers found)

7. Validating Cosmos DB databases exist...
   [PASS] Database exists: groupsToResourcesMap
   [PASS] Database exists: UserInformation
   [PASS] Database exists: conversations
   [PASS] Database exists: statusdb

8. Validating Cosmos DB containers exist...
   [PASS] Container exists: groupsToResourcesMap/groupResourcesMapContainer
   [PASS] Container exists: UserInformation/group_management
   [PASS] Container exists: conversations/chat_history_session
   [PASS] Container exists: statusdb/statuscontainer

======================================================================
  PRE-FLIGHT VALIDATION SUMMARY
======================================================================
  PASS: 22
  FAIL: 0
  SKIP: 0

[VALIDATION PASSED]

======================================================================
  POPULATING COSMOS DB
======================================================================

1. RBAC Group Mappings (groupResourcesMapContainer)
   [CREATED] Local Development - Admin
   [CREATED] Local Development - Contributor
   [CREATED] Local Development - Reader

2. Example Questions (group_management)
   [CREATED] Questions for Local Development - Admin
   [CREATED] Questions for Local Development - Contributor
   [CREATED] Questions for Local Development - Reader

======================================================================
  POPULATING BLOB STORAGE
======================================================================
   [EXISTS] Container already exists: documents
   [EXISTS] Container already exists: upload

======================================================================
  POST-POPULATION VERIFICATION
======================================================================

Verifying RBAC groups...
   [VERIFIED] 3/3 groups exist

Verifying example questions...
   [VERIFIED] 3/3 question sets exist

Verifying blob containers...
   [VERIFIED] 2/2 containers exist

[BACKUP] Saved to: populate-backup-20260205_073308.json

[EVIDENCE] Saved to: evidence\populate\populate_evidence_20260205_073308.json
[EVIDENCE] Operations: 12
[EVIDENCE] Errors: 0

[POPULATION COMPLETE]
```

---

## What Gets Created

### Cosmos DB Items

**groupResourcesMapContainer**: 3 items
- Admin group mapping
- Contributor group mapping
- Reader group mapping

**group_management**: 3 items
- Admin example questions
- Contributor example questions
- Reader example questions

### Blob Storage

**documents container**: Created (empty)
**upload container**: Verified (may already exist)

### Result

**Before Seeding**:
- App starts with errors
- Authorization fails (no groups)
- UI has no suggestion buttons
- Upload endpoint crashes (no containers)

**After Seeding**:
- App starts cleanly
- 3 roles authorized (Admin/Contributor/Reader)
- UI shows 3 example questions per role
- Upload ready (but no documents yet)
- Search returns empty (no indexed content)

---

## Next Steps for Complete Working Demo

### Phase 1: Infrastructure Seeding (Current Script)
✅ RBAC groups  
✅ Example questions  
✅ Blob containers

### Phase 2: Sample Document Processing
1. Upload sample PDF to `upload/` container
2. Trigger Azure Functions pipeline
3. Verify chunks written to `documents/`
4. Verify entries in `vector-index`

### Phase 3: Sample Conversations (Future Enhancement)
1. Create 1-2 pre-populated conversations
2. Write to `conversations/chat_history_session`
3. Shows app in "already used" state

---

## Integration with Self-Service Feature

**Goal**: One-click sandbox provisioning for developers

### Complete Flow

```
1. Developer clicks "Create Sandbox"
   └─> Terraform/Bicep deployment
       ├─> Provisions Azure resources
       ├─> Deploys backend/frontend
       └─> Triggers seeding script
           ├─> Populates RBAC groups
           ├─> Loads example questions
           ├─> Creates blob containers
           └─> (Optional) Uploads sample document
                └─> Azure Functions process
                    └─> Search index populated

2. Developer receives sandbox URL
   └─> Opens app
       ├─> Logs in (SSO)
       ├─> Authorization works (RBAC seeded)
       ├─> Sees example questions (UI seeded)
       ├─> Clicks question
       └─> Gets answer (sample doc processed)

Result: Working demo in <5 minutes
```

### Automation Script Structure

**File**: `provision-sandbox.ps1` (Future)
```powershell
# 1. Infrastructure
.\Deploy-Infrastructure.ps1 -EnvironmentName "sandbox-$UserId"

# 2. Application
.\Deploy-Application.ps1 -EnvironmentName "sandbox-$UserId"

# 3. Seeding
python populate-marco-sandbox-complete.py --force

# 4. (Optional) Sample Document
.\Upload-Sample-Document.ps1 -EnvironmentName "sandbox-$UserId"

# 5. Verification
.\Test-Sandbox.ps1 -EnvironmentName "sandbox-$UserId"
```

---

## Lessons Learned

### Critical Design Decisions

**1. Pre-Flight Validation Before Imports**
- **Problem**: Script failed on line 130 with `ModuleNotFoundError` before pre-flight could run
- **Solution**: Check packages with `__import__()` in try/except BEFORE conditional imports
- **Result**: Pre-flight catches missing packages with helpful error message

**2. Conditional Imports with Globals**
```python
# Set to None initially
CosmosClient = None
BlobServiceClient = None

def import_azure_packages():
    global CosmosClient, BlobServiceClient
    try:
        from azure.cosmos import CosmosClient as _CosmosClient
        CosmosClient = _CosmosClient
    except ImportError:
        pass
```
- Prevents import failures from blocking script execution
- Pre-flight can detect and report missing packages gracefully

**3. PowerShell Here-String Quoting Issues**
- **Problem**: Created script via PowerShell here-string embedded quotes incorrectly
- **Solution**: Use proper Python string quoting, not escaped here-string quotes
- **Wrong**: `with open(backend_env, '"'"'r'"'"')`
- **Right**: `with open(backend_env, 'r')`

**4. Evidence Collection at Boundaries**
- Every major operation logs to structured JSON
- Enables debugging without running full script
- Provides audit trail for compliance

**5. Rollback Capability Required**
- Backup file created before any writes
- Format: `{"timestamp": "...", "created_items": [...]}`
- Enables safe experimentation

---

## Future Enhancements

### Phase 2: Document Processing Integration
- Auto-upload sample PDFs during seeding
- Trigger Azure Functions pipeline programmatically
- Wait for indexing completion
- Verify search index populated

### Phase 3: Conversation Pre-Population
- Template for realistic Q&A exchanges
- Multiple conversation scenarios per role
- Demonstrates UI in "used" state

### Phase 4: Multi-Sandbox Management
- Track multiple sandboxes per developer
- Cleanup expired sandboxes
- Resource tagging for cost tracking

### Phase 5: Custom Templates
- Allow developers to choose content domain
- Template library (HR, Legal, Technical, etc.)
- Custom sample documents per domain

---

## References

**Source Code**:
- Populate Script: `I:\EVA-JP-v1.2\populate-marco-sandbox-complete.py`
- Data Preview: `I:\EVA-JP-v1.2\POPULATE-DATA-PREVIEW.md`
- Backend Config: `I:\EVA-JP-v1.2\app\backend\backend.env.marco-sandbox`

**Related Documentation**:
- Original Seeder: `I:\EVA-JP-v1.2\SEED-DATA-PACKAGE.md`
- Design Review: `I:\EVA-JP-v1.2\SEEDER-DESIGN-REVIEW.md`
- Professional Components: `I:\EVA-JP-v1.2\.github\copilot-instructions.md`

**Azure Resources** (marco-sandbox):
- Cosmos DB: `marco-sandbox-cosmos`
- Storage: `marcosand20260203`
- Search: `marco-sandbox-search`

---

## Summary

The seeding process transforms an **empty EVA-JP deployment** into a **working demo environment** by:

1. **Populating RBAC groups** - Authorization works
2. **Loading example questions** - UI displays prompts
3. **Creating blob containers** - Upload pipeline ready
4. **(Future) Processing sample documents** - Q&A works
5. **(Future) Pre-loading conversations** - Shows "used" state

**Current Script**: Handles steps 1-3 with professional-grade validation, logging, and rollback capabilities.

**Goal**: Enable one-click sandbox provisioning for developers with a working EVA-JP instance in <5 minutes.

**Status**: Infrastructure seeding complete. Document processing integration next.
