# EsDAICoE-Sandbox Architecture Diagram

**Last Updated**: February 3, 2026  
**Owner**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Status**: READY TO DEPLOY

---

## Current State: EsDAICoE-Sandbox Resource Group

```
┌─────────────────────────────────────────────────────────────────┐
│                    EsDAICoE-Sandbox (Canada Central)            │
│                   Subscription: EsDAICoESub                      │
│                  Owner: marco.presta@hrsdc-rhdcc.gc.ca          │
│                  Expiry: April 17, 2026                         │
└─────────────────────────────────────────────────────────────────┘
                            [EMPTY RG]
                     Ready for your deployment!
```

---

## Proposed Architecture: RAG System Sandbox

### High-Level Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         USERS / DEVELOPERS                            │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       FRONTEND (Browser)                              │
│                    React + TypeScript SPA                             │
│                    http://localhost:5173 (dev)                        │
│              http://marco-sandbox-backend.azurewebsites.net (prod)    │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ REST API / SSE
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    BACKEND API (Web App B1)                           │
│                  marco-sandbox-backend.azurewebsites.net              │
│                     Python/Quart Async Server                         │
│                                                                        │
│  Endpoints: /chat, /ask, /upload, /documents, /sessions, /health     │
└─────┬──────────────┬──────────────┬──────────────┬────────────────────┘
      │              │              │              │
      │ Query        │ Documents    │ Embeddings   │ Sessions/Logs
      ▼              ▼              ▼              ▼
┌─────────────┐ ┌──────────────┐ ┌─────────────┐ ┌──────────────┐
│   REUSED    │ │  NEW DEPLOY  │ │  NEW DEPLOY │ │  NEW DEPLOY  │
│   SERVICES  │ │   SERVICES   │ │   SERVICE   │ │   SERVICES   │
└─────────────┘ └──────────────┘ └─────────────┘ └──────────────┘
```

---

## Best Practices Alignment

**This sandbox demonstrates Azure best practices from Project 18**:
- ✅ Cost management automation (Module 02)
- ✅ Infrastructure as code with Terraform (Module 04)
- ✅ Professional component architecture (EVA Foundation)
- 🔄 Monitoring alerts recommended (Module 01)
- 🔴 AI Red Teaming critical for RAG (Module 11)

**Compliance Checklist**: See `BEST-PRACTICES-COMPLIANCE.md`  
**Source Repository**: `I:\eva-foundation\18-azure-best` (11 modules)  
**ROI**: $107K-$557K/year from recommended enhancements

---

## Detailed Component Architecture

### A. REUSED SERVICES (No Deployment Needed)

```
┌─────────────────────────────────────────────────────────────┐
│         EXISTING infoasst-dev2 RESOURCES (Canada East)      │
│                    [NO CHANGES REQUIRED]                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. infoasst-aoai-dev2 (Azure OpenAI S0)                    │
│     Endpoint: https://infoasst-aoai-dev2.openai.azure.com   │
│     Deployments:                                             │
│       - gpt-4o (128k context)                               │
│       - dev2-text-embedding (ada-002)                       │
│     Cost: SHARED (no additional charge)                     │
│     Usage: Chat completions + embeddings                    │
│                                                               │
│  2. infoasst-docint-dev2 (Document Intelligence S0)         │
│     Endpoint: https://infoasst-docint-dev2.cognitiveservices.azure.com │
│     Cost: SHARED (no additional charge)                     │
│     Usage: PDF OCR processing in Functions pipeline         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Why Reuse?**
- Azure OpenAI: $200+/month for dedicated instance vs $0 for shared quota
- Document Intelligence: $5-50/month vs $0 for shared
- **Total Savings**: ~$205-250/month

---

### B. NEW DEPLOYMENTS (12 Resources in EsDAICoE-Sandbox)

#### 1. Search Layer

```
┌─────────────────────────────────────────────────────────┐
│  marco-sandbox-search (Cognitive Search - Basic)        │
│  Location: Canada Central                               │
│  SKU: Basic ($75/month)                                 │
│  Purpose: Hybrid vector + keyword search                │
│                                                           │
│  Index: index-jurisprudence                             │
│  Features:                                               │
│    - Vector search (1536-dim embeddings)                │
│    - Keyword search (BM25)                              │
│    - Semantic ranking                                   │
│                                                           │
│  Difference from Dev2:                                  │
│    Dev2: Standard S1 ($250/month)                       │
│    Sandbox: Basic ($75/month) - 70% cost reduction      │
└─────────────────────────────────────────────────────────┘
```

#### 2. Data Storage Layer

```
┌─────────────────────────────────────────────────────────┐
│  marco-sandbox-cosmos (Cosmos DB - Serverless)          │
│  Location: Canada Central                               │
│  SKU: Serverless (pay-per-use)                          │
│  Cost: ~$5-10/month                                     │
│  Purpose: Session logs, user state, audit logs          │
│                                                           │
│  Databases:                                              │
│    - conversations (session data)                       │
│    - audit (operation logs)                             │
│                                                           │
│  Difference from Dev2:                                  │
│    Dev2: Provisioned throughput (~$50/month)            │
│    Sandbox: Serverless (~$8/month) - 84% reduction      │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  marcosandboxstore20260203 (Blob Storage)               │
│  Location: Canada Central                               │
│  SKU: Standard_LRS (locally redundant)                  │
│  Cost: ~$5/month                                        │
│  Purpose: Document blob storage                         │
│                                                           │
│  Containers:                                             │
│    - documents (uploaded PDFs)                          │
│    - enriched-documents (processed chunks)              │
│    - text-enrichment-queue (Function triggers)          │
│                                                           │
│  PUBLIC Endpoint with IP Firewall Rules                 │
│  (No VNet/Private Endpoint - cost savings)              │
└─────────────────────────────────────────────────────────┘
```

#### 3. Compute Layer

```
┌─────────────────────────────────────────────────────────┐
│  BACKEND API                                             │
│  marco-sandbox-backend (Web App - Linux)                │
│  SKU: B1 ($13/month)                                    │
│  App Service Plan: marco-sandbox-asp-backend (B1)      │
│                                                           │
│  Purpose: Python/Quart RAG API server                   │
│  Endpoints: /chat, /ask, /upload, /documents, /health  │
│                                                           │
│  Difference from Dev2:                                  │
│    Dev2: P1V2 ($73/month)                               │
│    Sandbox: B1 ($13/month) - 82% cost reduction         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  ENRICHMENT SERVICE                                      │
│  marco-sandbox-enrichment (Web App - Linux)             │
│  SKU: B1 ($13/month)                                    │
│  App Service Plan: marco-sandbox-asp-enrichment (B1)   │
│                                                           │
│  Purpose: Flask API for embedding generation            │
│  Endpoint: /embeddings                                  │
│                                                           │
│  Calls: infoasst-aoai-dev2 (dev2-text-embedding)       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  DOCUMENT PIPELINE                                       │
│  marco-sandbox-func (Function App - Linux)              │
│  SKU: Consumption (pay-per-execution)                   │
│  App Service Plan: marco-sandbox-asp-func (Consumption) │
│  Cost: ~$1-5/month                                      │
│                                                           │
│  Functions:                                              │
│    1. FileUploadedEtrigger (blob trigger)               │
│       └─> Starts pipeline on document upload            │
│    2. FileFormRecSubmissionPDF (HTTP trigger)           │
│       └─> OCR via infoasst-docint-dev2                 │
│    3. TextEnrichment (queue trigger)                    │
│       └─> Chunking + embedding + indexing               │
│                                                           │
│  Difference from Dev2:                                  │
│    Dev2: Dedicated plan (~$50/month)                    │
│    Sandbox: Consumption (~$3/month) - 94% reduction     │
└─────────────────────────────────────────────────────────┘
```

#### 4. Security & Monitoring

```
┌─────────────────────────────────────────────────────────┐
│  marco-sandbox-kv-20260203 (Key Vault - Standard)      │
│  Cost: ~$0.03/month                                     │
│  Purpose: Secrets management                            │
│    - Azure OpenAI API keys                              │
│    - Storage account keys                               │
│    - Cosmos DB connection strings                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  marcosandboxacr20260203 (Container Registry - Basic)   │
│  Cost: ~$5/month                                        │
│  Purpose: Docker image storage                          │
│    - Backend API image                                  │
│    - Enrichment service image                           │
│    - Function app image                                 │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  marco-sandbox-appinsights (Application Insights)       │
│  Cost: SHARED with dev2 Log Analytics                   │
│  Purpose: Telemetry, performance monitoring, logs       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Managed Identities (x2) - System Assigned              │
│  Cost: FREE                                             │
│  Purpose: Passwordless authentication between services  │
└─────────────────────────────────────────────────────────┘
```

#### 5. API Management Layer (Phase 2)

```
┌─────────────────────────────────────────────────────────┐
│  APIM GATEWAY                                            │
│  marco-sandbox-apim (API Management - Developer SKU)    │
│  Cost: $50/month                                        │
│  Location: Canada Central                               │
│  Status: ACTIVATING (deployed Feb 3, 2026)             │
│                                                           │
│  Purpose: API gateway with rate limiting, monitoring    │
│  Capabilities:                                           │
│    - Request throttling (500 calls/min)                 │
│    - API versioning & routing                           │
│    - Usage analytics & cost tracking                    │
│    - Authentication policies                            │
│                                                           │
│  Backend API Endpoints:                                 │
│    /chat     -> marco-sandbox-backend:5000/chat        │
│    /ask      -> marco-sandbox-backend:5000/ask         │
│    /upload   -> marco-sandbox-backend:5000/upload      │
│    /health   -> marco-sandbox-backend:5000/health      │
│                                                           │
│  Deployment Duration: ~20 minutes                       │
└─────────────────────────────────────────────────────────┘
```

#### 6. FinOps Hub - Cost Analytics (Phase 3)

```
┌─────────────────────────────────────────────────────────┐
│  FINOPS STORAGE ACCOUNT                                  │
│  marcosandboxfinopshub (Storage - Data Lake Gen2)       │
│  Cost: $15/month                                        │
│  Location: Canada Central                               │
│  Status: QUEUED (auto-deploys after Phase 2)           │
│                                                           │
│  Purpose: Cost export data lake storage                 │
│  Containers:                                             │
│    - costs/          (daily cost exports)               │
│    - raw/            (raw CSV from Cost Management)     │
│    - processed/      (transformed parquet)              │
│                                                           │
│  Features:                                               │
│    - Hierarchical namespace (ADLS Gen2)                 │
│    - LRS redundancy                                      │
│    - Cool tier storage                                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  FINOPS DATA FACTORY                                     │
│  marco-sandbox-finops-adf (Data Factory v2)             │
│  Cost: $10/month                                        │
│  Status: QUEUED (auto-deploys after Phase 2)           │
│                                                           │
│  Purpose: Cost data ingestion & transformation          │
│  Pipelines:                                              │
│    1. IngestDailyCosts                                  │
│       └─> Triggered by cost export completion           │
│    2. TransformCostData                                 │
│       └─> CSV to Parquet conversion                     │
│    3. AggregateByResource                               │
│       └─> Daily/Monthly cost rollups                    │
│                                                           │
│  Linked Services:                                        │
│    - marcosandboxfinopshub (source)                     │
│    - Azure Cost Management API (raw data)               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  COST MANAGEMENT EXPORT                                  │
│  marco-sandbox-costs-daily (Daily Export Schedule)      │
│  Cost: $40/month (included in Cost Management)          │
│  Status: QUEUED (auto-configures after Phase 2)        │
│                                                           │
│  Purpose: Automated daily cost data export              │
│  Configuration:                                          │
│    - Scope: EsDAICoE-Sandbox resource group             │
│    - Schedule: Daily at 00:00 UTC                       │
│    - Format: CSV (ActualCost dataset)                   │
│    - Destination: marcosandboxfinopshub/costs/          │
│                                                           │
│  Data Includes:                                          │
│    - Resource-level costs (daily granularity)           │
│    - Tags: Owner, Environment, Project                  │
│    - Meter details: Usage quantity, unit price          │
│    - Currency: CAD                                       │
└─────────────────────────────────────────────────────────┘
```

---

## Data Flow: Document Upload → Chat Query

```
┌──────────────────────────────────────────────────────────────────────┐
│                       DOCUMENT INGESTION PIPELINE                     │
└──────────────────────────────────────────────────────────────────────┘

1. User uploads PDF
   │
   ▼
2. marcosand20260203/documents container
   │
   ▼
3. FileUploadedEtrigger (marco-sandbox-func) fires
   │
   ▼
4. FileFormRecSubmissionPDF calls infoasst-docint-dev2 (REUSED)
   │  └─> OCR extracts text from PDF
   │
   ▼
5. Writes to text-enrichment-queue
   │
   ▼
6. TextEnrichment function processes
   │  ├─> Chunks text (1000 tokens, 200 overlap)
   │  ├─> Calls marco-sandbox-enrichment for embeddings
   │  │   └─> Enrichment calls infoasst-aoai-dev2/dev2-text-embedding (REUSED)
   │  └─> Indexes to marco-sandbox-search/index-jurisprudence
   │
   ▼
7. Document ready for RAG queries

┌──────────────────────────────────────────────────────────────────────┐
│                           CHAT QUERY FLOW                             │
└──────────────────────────────────────────────────────────────────────┘

1. User sends chat message via Frontend
   │
   ▼
2. marco-sandbox-backend receives /chat request
   │
   ▼
3. Query optimization (optional Azure AI Services)
   │
   ▼
4. Generate query embedding
   │  └─> Calls infoasst-aoai-dev2/dev2-text-embedding (REUSED)
   │
   ▼
5. Hybrid search in marco-sandbox-search
   │  ├─> Vector search (query embedding vs document embeddings)
   │  └─> Keyword search (BM25)
   │
   ▼
6. Retrieve top 5 relevant document chunks
   │
   ▼
7. Assemble prompt with context
   │
   ▼
8. Call infoasst-aoai-dev2/gpt-4o for completion (REUSED)
   │
   ▼
9. Stream response back to Frontend (SSE)
   │
   ▼
10. Log session to marco-sandbox-cosmos
```

---

## Naming Convention Strategy

### Current Naming Pattern in Deploy Script

```powershell
$namePrefix = "marco-sandbox"

Resources:
- marco-sandbox-search          [Search: Basic]
- marco-sandbox-cosmos          [Cosmos DB: Serverless]
- marcosand20260203             [Storage: must be lowercase, no hyphens, 24 char limit]
- marco-sandbox-backend         [Web App: Backend API]
- marco-sandbox-enrichment      [Web App: Enrichment Service]
- marco-sandbox-func            [Function App]
- marco-sandbox-asp-backend     [App Service Plan]
- marco-sandbox-asp-enrichment  [App Service Plan]
- marco-sandbox-asp-func        [App Service Plan]
- marco-sandbox-kv-20260203     [Key Vault]
- marcosandboxacr20260203       [Container Registry: must be lowercase]
- marco-sandbox-appinsights     [App Insights]
```

### Why This Convention?

**Ownership Clarity**:
- `marco-` prefix immediately identifies owner: Marco Presta
- `sandbox-` indicates environment: non-production testing

**Service Type Clarity**:
- `-search`, `-cosmos`, `-backend`, `-enrichment`, `-func` = clear purpose
- `-asp-*` = App Service Plans (infrastructure layer)
- `-kv-*` = Key Vault

**Timestamp for Global Uniqueness**:
- Storage accounts require globally unique names (26M+ Azure storage accounts exist)
- Container Registry requires globally unique names
- Key Vault requires globally unique names
- Solution: Add date suffix `20260203` to guarantee uniqueness

**Difference from Dev2 Naming**:
```
Dev2:       infoasst-aoai-dev2, infoasst-search-dev2, infoasst-web-dev2
            └─ Team/project prefix, environment suffix

Sandbox:    marco-sandbox-search, marco-sandbox-backend
            └─ Owner prefix, environment infix, service suffix

Benefits:
- CLEAR who owns the resource (marco vs team)
- CLEAR it's sandbox/test environment
- CLEAR what the service does
```

---

## Cost Breakdown: What You're Deploying

| Resource | Monthly Cost | Why You Need It |
|----------|--------------|-----------------|
| **marco-sandbox-search** | $75 | Cannot reuse dev2 Search (index isolation, permission model) |
| **marco-sandbox-cosmos** | $8 | Cannot reuse dev2 Cosmos (separate session logs, no production data leakage) |
| **marcosandboxstore** | $5 | Cannot reuse dev2 Storage (document isolation, permission boundary) |
| **marco-sandbox-backend** | $13 | Your backend API instance (cannot share Web App with dev2) |
| **marco-sandbox-enrichment** | $13 | Your enrichment service (cannot share Web App with dev2) |
| **marco-sandbox-func** | $3 | Your document pipeline (cannot share Function App with dev2) |
| **marcosandboxacr** | $5 | Your container images (could potentially reuse dev2, but isolation safer) |
| **marco-sandbox-kv** | $0.03 | Your secrets (cannot share Key Vault for security) |
| **App Insights** | $0 | Shared Log Analytics workspace |
| **App Service Plans (x3)** | $0 | Included in Web App costs |
| **Managed Identities (x2)** | $0 | Free service |
| **SUB-TOTAL (Phase 1)** | **$122/month** | Base RAG system |
| **marco-sandbox-apim** (Phase 2) | $50 | API Management Gateway (Developer SKU) |
| **marcosandboxfinopshub** (Phase 3) | $15 | FinOps Storage (Data Lake Gen2) |
| **marco-sandbox-finops-adf** (Phase 3) | $10 | FinOps Data Factory (ingestion pipelines) |
| **Cost Export** (Phase 3) | $0 | Included in Azure Cost Management |
| **TOTAL (All Phases)** | **$197/month** | With APIM + FinOps Hub |

**DEPLOYMENT STATUS**:
- ✅ Phase 1 (Base RAG): 12/12 resources deployed
- ⏳ Phase 2 (APIM): 1/1 resource activating (~3-4 min remaining)
- ⏳ Phase 3 (FinOps): 3/3 resources queued (auto-starts after Phase 2)

**NOT Deploying** (Reusing from dev2):
- Azure OpenAI: $200+/month SAVED
- Document Intelligence: $5-50/month SAVED
- **Total Savings**: $205-250/month

---

## Deployment Decision Matrix

| Service | Deploy New? | Reuse Dev2? | Rationale |
|---------|-------------|-------------|-----------|
| Azure OpenAI | ❌ No | ✅ Yes | Can share quota, expensive ($200+/month), no data leakage risk |
| Document Intelligence | ❌ No | ✅ Yes | Stateless OCR service, no data retention, $5-50/month saved |
| Cognitive Search | ✅ Yes | ❌ No | Indexes must be isolated, permission model doesn't support sharing |
| Cosmos DB | ✅ Yes | ❌ No | Session logs must be isolated, no production data leakage |
| Blob Storage | ✅ Yes | ❌ No | Documents must be isolated, permission boundary required |
| Web Apps (x2) | ✅ Yes | ❌ No | Cannot share compute, separate deployment pipelines |
| Function App | ✅ Yes | ❌ No | Cannot share compute, separate pipeline execution |
| Key Vault | ✅ Yes | ❌ No | Secrets isolation, security boundary |
| Container Registry | ✅ Yes | ❌ Maybe | Could reuse, but safer to isolate your images |
| App Insights | ❌ No | ✅ Yes | Can share Log Analytics workspace, no sensitive data |

---

## Next Steps

1. **Review this architecture** - Does it meet your needs?
2. **Confirm naming convention** - Is `marco-sandbox-*` acceptable?
3. **Run deployment preview**: `.\Deploy-Sandbox-AzCLI.ps1 -WhatIf`
4. **Execute deployment**: `.\Deploy-Sandbox-AzCLI.ps1`
5. **Post-deployment config** - Connect to infoasst-aoai-dev2, deploy application code

---

## Questions to Consider

1. **Naming**: Do you want `marco-sandbox-*` or different prefix?
   - Alternative: `mp-sandbox-*` (your initials)
   - Alternative: `presta-sandbox-*` (your last name)
   - Alternative: `eva-poc-*` (project-based naming)

2. **Resource Reuse**: Should Container Registry be shared with dev2?
   - Pro: Save $5/month
   - Con: Potential image version conflicts

3. **Monitoring**: Use shared App Insights or deploy new instance?
   - Current: Shared (recommended for cost)
   - Alternative: Deploy new ($0-20/month depending on telemetry volume)

---

**Last Updated**: February 3, 2026  
**Owner**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)
