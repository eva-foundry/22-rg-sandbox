# EsDAICoE-Sandbox Resource Inventory

**Date**: February 4, 2026  
**Resource Group**: EsDAICoE-Sandbox  
**Subscription**: EsDAICoESub (d2d4e571-e0f2-4f6c-901a-f88f7669bcba)  
**Total Resources**: 17 active marco* resources  
**Data Source**: Azure Resource Manager API (az resource list)

---

## Executive Summary

**Deployment Status**: Phase 1-2 Complete, Phase 3 Partial (50%)  
**Total Monthly Cost**: $182/month  
**Cost Optimization**: -$5/month from duplicate ACR removal (Feb 4, 2026)  
**Owner**: marco.presta@hrsdc-rhdcc.gc.ca (Owner role until April 17, 2026)

---

## Phase 1: Base RAG System (12 resources) - ✅ 100% Complete

### AI/ML Services (2 resources)

| Resource | Type | SKU | Purpose | Monthly Cost |
|----------|------|-----|---------|--------------|
| **marco-sandbox-search** | Azure Cognitive Search | Basic | Hybrid vector + keyword search | $75 |
| **marco-sandbox-openai** | Azure OpenAI | S0 | GPT-4 completions, embeddings | Reused from Dev2 |

**Subtotal AI/ML**: $75/month

---

### Data Storage (2 resources)

| Resource | Type | SKU | Purpose | Monthly Cost |
|----------|------|-----|---------|--------------|
| **marco-sandbox-cosmos** | Cosmos DB | Serverless | Session logs, chat history | $10 |
| **marcosand20260203** | Storage Account | Standard_LRS | Document storage, blobs | $5 |

**Subtotal Storage**: $15/month

---

### Compute Resources (6 resources)

| Resource | Type | SKU | Purpose | Monthly Cost |
|----------|------|-----|---------|--------------|
| **marco-sandbox-backend** | Web App | - | Backend API (Quart/Python) | Runs on ASP |
| **marco-sandbox-enrichment** | Web App | - | Embedding service (Flask) | Runs on ASP |
| **marco-sandbox-func** | Function App | Consumption | Document pipeline (OCR, chunking) | $2 |
| **marco-sandbox-asp-backend** | App Service Plan | B1 | Hosts backend web app | $13 |
| **marco-sandbox-asp-enrichment** | App Service Plan | B1 | Hosts enrichment service | $13 |
| **marco-sandbox-asp-func** | App Service Plan | Y1 | Hosts function app | Included |

**Subtotal Compute**: $28/month

---

### Infrastructure (2 resources)

| Resource | Type | SKU | Purpose | Monthly Cost |
|----------|------|-----|---------|--------------|
| **marcosandkv20260203** | Key Vault | Standard | Secrets, connection strings | $1 |
| **marcosandacr20260203** | Container Registry | Basic | Docker images | $5 |

**Subtotal Infrastructure**: $6/month

---

## Phase 2: APIM Gateway (1 resource) - ✅ 100% Complete

| Resource | Type | SKU | Purpose | Monthly Cost |
|----------|------|-----|---------|--------------|
| **marco-sandbox-apim** | API Management | Developer | API gateway, rate limiting | $50 |

**Subtotal APIM**: $50/month

---

## Phase 3: FinOps Hub (2/4 components) - ⚠️ 50% Complete

### Deployed Components (2 resources)

| Resource | Type | SKU | Purpose | Monthly Cost |
|----------|------|-----|---------|--------------|
| **marcosandboxfinopshub** | Storage Account | Standard_LRS | Cost export storage | $3 |
| **marco-sandbox-finops-adf** | Data Factory | - | Cost data pipelines | $5 |

**Subtotal FinOps (Deployed)**: $8/month

---

### Pending Components

| Component | Status | Blocker | Estimated Cost |
|-----------|--------|---------|----------------|
| **Cost Export (EsDAICoESub)** | ⏳ Pending | Storage Blob Data Contributor permission | Included |
| **Cost Export (EsPAICoESub)** | ⏳ Pending | Storage Blob Data Contributor permission | Included |
| **Data Factory Pipelines (3)** | ⏳ Ready | JSON definitions created, awaiting cost data | Included in $5 |

**Estimated When Complete**: +$0/month (no additional cost)

---

## Resource Naming Patterns

### Primary Services Pattern
**Format**: `marco-sandbox-{service}`  
**Examples**: marco-sandbox-search, marco-sandbox-cosmos, marco-sandbox-backend  
**Used For**: Main application services

### Storage/Constrained Pattern
**Format**: `marcosand{service}20260203`  
**Examples**: marcosand20260203, marcosandkv20260203, marcosandacr20260203  
**Used For**: Storage accounts, Key Vault, ACR (24-char Azure limit)  
**Date Suffix**: 20260203 = February 3, 2026 (creation date)

### FinOps Pattern
**Format**: `marcosandbox{purpose}`  
**Examples**: marcosandboxfinopshub (FinOps Hub storage)  
**Used For**: FinOps Toolkit standard naming

---

## Cost Breakdown Summary

| Phase | Resources | Monthly Cost | Status |
|-------|-----------|--------------|--------|
| **Phase 1: RAG System** | 12 | $124 | ✅ Complete |
| **Phase 2: APIM Gateway** | 1 | $50 | ✅ Complete |
| **Phase 3: FinOps Hub** | 2/4 | $8 | ⚠️ Partial |
| **TOTAL** | 17 | **$182/month** | **In Progress** |

**Projected Cost (Phase 3 Complete)**: $182/month (no change - pipelines included)  
**Cost Optimization Achieved**: -$5/month (duplicate ACR removed Feb 4, 2026)

---

## Resource Creation Timeline

| Date | Resources Created | Event |
|------|-------------------|-------|
| **Feb 3, 2026** | Phase 1 (12), Phase 2 (1), Phase 3 storage (1) | Initial deployment |
| **Feb 4, 2026** | Data Factory (1) | Phase 3 FinOps Hub continuation |
| **Feb 4, 2026** | Duplicate ACR removed (1) | Cost optimization |

---

## Detailed Resource Specifications

### Azure Cognitive Search: marco-sandbox-search
- **SKU**: Basic
- **Replicas**: 1
- **Partitions**: 1
- **Storage**: 2 GB
- **Index**: index-jurisprudence (hybrid vector + keyword)
- **Monthly Cost**: $75

### Cosmos DB: marco-sandbox-cosmos
- **SKU**: Serverless (pay-per-use)
- **Database**: conversations
- **Containers**: sessions, logs
- **Estimated Usage**: Low (PoC traffic)
- **Monthly Cost**: ~$10

### Azure OpenAI: marco-sandbox-openai
- **Reused From**: infoasst-aoai-dev2
- **Models**: gpt-4, text-embedding-ada-002
- **Quota Sharing**: Shared with Dev2
- **Monthly Cost**: $0 (reused resource)

### App Service Plans
- **Backend ASP**: B1 (1 core, 1.75 GB RAM) - $13/month
- **Enrichment ASP**: B1 (1 core, 1.75 GB RAM) - $13/month
- **Function ASP**: Y1 Consumption - Included

### Storage Accounts
- **marcosand20260203**: Standard_LRS, 5 GB documents - $5/month
- **marcosandboxfinopshub**: Standard_LRS, cost exports - $3/month

### Container Registry
- **marcosandacr20260203**: Basic, backend/enrichment images - $5/month

### API Management
- **marco-sandbox-apim**: Developer tier, 1 unit - $50/month

### Data Factory
- **marco-sandbox-finops-adf**: Pay-per-pipeline-run - ~$5/month

---

## Access Control

**Owner Role (marco.presta@hrsdc-rhdcc.gc.ca)**:
- Scope: EsDAICoE-Sandbox resource group
- Expires: April 17, 2026 (PIM eligible)
- Capabilities: Full resource management, RBAC assignment

**Cost Management Contributor**:
- Scope: EsDAICoESub subscription
- Scope: EsPAICoESub subscription
- Capabilities: Create cost exports, view cost data

**Pending Permission** (Phase 3 blocker):
- Role: Storage Blob Data Contributor
- Scope: marcosandboxfinopshub storage account
- Required For: Cost Management service to write export CSVs

---

## Phase 3 Completion Requirements

### 1. Permission Request (IT)
```bash
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "marco.presta@hrsdc-rhdcc.gc.ca" \
  --scope "/subscriptions/d2d4e571-.../storageAccounts/marcosandboxfinopshub"
```

### 2. Cost Export Creation (Azure Portal)
- Export 1: esdaicoesub-costs-daily (Sandbox costs)
- Export 2: espaicoesub-costs-daily (Production costs)
- Destination: marcosandboxfinopshub / costs container

### 3. Pipeline Deployment (Azure CLI)
- Deploy IngestDailyCosts.json
- Deploy TransformCostData.json
- Deploy AggregateByResource.json
- Estimated Time: 15 minutes

### 4. Verification
- Check cost export CSVs in storage
- Trigger pipelines manually
- Verify aggregated cost reports

**Estimated Completion Time**: 1 hour (after permission granted)

---

## Evidence Files

- **Resource Inventory JSON**: `inventory/deployed/marco-resources-complete-20260204.json`
- **Deployment Status**: `DEPLOYMENT-STATUS-CURRENT.md`
- **Audit Report**: `AUDIT-REPORT-20260204.md`
- **TODO List**: `TODO-COMPLETION-20260204.md`
- **Pipeline Definitions**: `I:\eva-foundation\14-az-finops\scripts\pipelines\`

---

## Next Actions

1. ✅ **Data Factory deployed** - marco-sandbox-finops-adf created
2. ✅ **Duplicate ACR removed** - marcosandboxacr20260203 deleted (-$5/month)
3. ✅ **Pipeline definitions ready** - 3 JSON files created
4. ⏳ **Awaiting IT**: Storage Blob Data Contributor permission on marcosandboxfinopshub
5. ⏳ **After permission**: Create 2 cost exports, deploy 3 pipelines, verify data flow

---

**Last Updated**: February 4, 2026 19:30 EST  
**Document Owner**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Verification Method**: Azure CLI direct enumeration (az resource list)
