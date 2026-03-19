# Project 22: EsDAICoE-Sandbox Deployment

<!-- eva-primed -->
<!-- foundation-primer: 2026-03-03 by agent:copilot -->

## EVA Ecosystem Integration

| Tool | Purpose | How to Use |
|------|---------|------------|
| 37-data-model | Single source of truth for all project entities | GET http://localhost:8010/model/projects/22-rg-sandbox |
| 29-foundry | Agentic capabilities (search, RAG, eval, observability) | C:\eva-foundry\eva-foundation\29-foundry |
| 48-eva-veritas | Trust score and coverage audit | MCP tool: audit_repo / get_trust_score |
| 07-foundation-layer | Copilot instructions primer + governance templates | MCP tool: apply_primer / audit_project |

**Agent rule**: Query the data model API before reading source files.
```powershell
Invoke-RestMethod "http://localhost:8010/model/agent-guide"   # complete protocol
Invoke-RestMethod "http://localhost:8010/model/agent-summary" # all layer counts
```

---


**Project Status**: ?? PHASE 3 IN PROGRESS (50%) - [Status](./DEPLOYMENT-STATUS-CURRENT.md) | [Inventory](./RESOURCE-INVENTORY-20260204.md) | [Cost Analysis](./COST-ANALYSIS-20260204.md) | [Audit](./PROJECT-22-COMPREHENSIVE-AUDIT.md)  
**Owner**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Subscription**: EsDAICoESub (d2d4e571-e0f2-4f6c-901a-f88f7669bcba)  
**Resource Group**: EsDAICoE-Sandbox (Owner until April 17, 2026)  
**Location**: Canada Central  
**Current Cost**: $182/month (18 active resources, 79% savings vs. Dev2)  
**Deployment Progress**: Phase 1 ? Complete (12 resources, $124/mo) | Phase 2 ? Complete (1 resource, $50/mo) | Phase 3 ?? Partial (2/4 components, $8/mo) | [Phase 4 Plan](./PHASE4-PLAN.md) Ready  
**Cost Performance**: ? Within 6% of estimate ($172 planned, $182 actual)  
**Overall Completion**: 75% (6/8 criteria met)  
**Last Verified**: February 4, 2026 via Azure CLI resource enumeration  
**Housekeeping**: [Archive](./archive/) contains superseded documentation (33 files archived Feb 4)  
**Knowledge Transfer**: ? [FinOps patterns documented in Project 14](./KNOWLEDGE-TRANSFER-COMPLETE.md) (9 reusable patterns)  
**Critical Blocker**: IT permission for Storage Blob Data Contributor (Cost Management exports)  
**Next Step**: Follow up on IT request (if no response in 48 hours), then Phase 3 completion (30 minutes) + Phase 4 implementation (3 weeks)

---

## Purpose

Deploy a cost-optimized RAG system PoC into the existing **EsDAICoE-Sandbox** resource group, cloning the EVA Dev2 (infoasst-dev2) architecture. This sandbox enables PoC development and testing with official ESDC tenant services (Azure OpenAI, APIM) without impacting production environments.

**Key Benefits**:
- ? **Immediate Access**: Owner role already active (no infrastructure team wait)
- ? **Full Control**: Owner permissions until April 17, 2026
- ? **Existing Infrastructure**: RG already provisioned in Canada Central
- ? **Cost-Optimized**: $100-150/month target maintained

---

## Frozen Scope (January 29, 2026)

### Architecture Decision: **Public Endpoints + Reuse Strategy**

After analyzing three options (full clone, minimal, hybrid), we locked on:

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Networking** | Public endpoints with firewall rules | 90% cost reduction (no VNet/private endpoints/NSGs/Bastion) |
| **Azure OpenAI** | Reuse existing infoasst-aoai-dev2 instance | Avoid $200+/month OpenAI costs, share quota |
| **Search** | Basic tier (new instance) | Dev2 uses Standard S1 ($250/month), Basic sufficient for PoC |
| **Cosmos DB** | Serverless (new instance) | Pay-per-use, <$10/month for low traffic |
| **Storage** | Standard_LRS (new instance) | Lowest-cost tier, no geo-redundancy needed |
| **Web Apps** | B1 tier (new instances) | $13/month vs. P1V2 $73/month |
| **Functions** | Consumption plan (new instance) | Pay-per-execution, near-zero idle cost |
| **Monitoring** | Reuse existing Log Analytics + App Insights | Share observability infrastructure |

**Cost Comparison**:
- **Dev2**: ~$500-1000/month (Standard S1 Search, P1V2 Web Apps, dedicated OpenAI, VNet infrastructure)
- **Sandbox**: ~$100-150/month (90% savings)

---

## Architecture Summary

### Resources to Deploy (12 total)

| Resource | SKU | Purpose | Monthly Cost |
|----------|-----|---------|--------------|
| Azure Cognitive Search | Basic | Hybrid vector+keyword search | $75 |
| Cosmos DB Account | Serverless | Session logs, metadata | $5-10 |
| Storage Account | Standard_LRS | Document blob storage | $5 |
| Web App (Backend) | B1 | Python/Quart API server | $13 |
| Web App (Enrichment) | B1 | Embedding generation | $13 |
| Function App | Consumption | Document pipeline (OCR, chunking) | $1-5 |
| Application Insights | Standard | Telemetry (shared) | $0 |
| Log Analytics Workspace | Standard | Logs (shared) | $0 |
| Key Vault | Standard | Secrets management | $0.03 |
| Container Registry | Basic | Docker images | $5 |
| Managed Identity (x2) | - | Service authentication | $0 |
| **TOTAL** | | | **~$117-131/month** |

**Reused Resources** (NO additional cost):
- Azure OpenAI: infoasst-aoai-dev2 (gpt-4o, dev2-text-embedding deployments)
- APIM: Pending confirmation from infrastructure team
- Monitoring: Log Analytics + App Insights from dev2

---

## Prerequisites (Before Deployment)

### 1. Permissions Required
- [x] **Current**: Reader + Cost Management Contributor on EsDAICoESub
- [ ] **Needed**: Contributor role on rg-sandbox-marco (infrastructure team to assign)

### 2. Infrastructure Team Confirmation
Send email with 3 critical questions:
1. **Network Policy**: Are public endpoints allowed for dev/test resource groups?
2. **APIM Access**: Can sandbox access existing APIM instance (infoasst-apim-dev2)?
3. **Azure OpenAI**: Confirmed reuse of infoasst-aoai-dev2 instance?

### 3. Pre-Deployment Inventory (Phase 1.1)
Capture while still have Reader access:
- [ ] Azure OpenAI quota status
- [ ] APIM instance list
- [ ] Policy assignments on subscription
- [ ] OpenAI deployment names
- [ ] Cost allocation tags

---

## Reference Architecture (Dev2 ? Sandbox Mapping)

### Dev2 (Source - 81 resources, validated 2026-02-03)
```
Core AI/ML Services (5):
  infoasst-aoai-dev2 (Azure OpenAI S0) - Canada East
  infoasst-aisvc-dev2 (AI Services S0) - Canada Central
  infoasst-docint-dev2 (Document Intelligence S0) - Canada Central
  infoasst-search-dev2 (Cognitive Search Standard) - Canada Central
  infoasst-cosmos-dev2 (Cosmos DB Provisioned) - Canada Central

Storage & Data (1):
  infoasststoredev2 (Storage Standard_LRS) - Canada Central
    ?? Private Endpoints: blob, file, queue, table (4)

Compute Layer (6):
  infoasst-web-dev2 (Web App - Linux container)
  infoasst-enrichmentweb-dev2 (Web App - Linux container)
  infoasst-func-dev2 (Function App - Linux container)
  infoasst-asp-dev2 (App Service Plan - Linux)
  infoasst-enrichmentasp-dev2 (App Service Plan - Linux)
  infoasst-func-asp-dev2 (App Service Plan - Linux)

Networking & Security (22):
  infoasst-vnet-dev2 (Virtual Network)
  15 Private Endpoints (all services locked down)
  1 Container Registry (infoasstacrdev2) with private endpoint
  2 Key Vaults (infoasst-kv-dev2, evachatdev2kv)
  1 NSG, 18 Private DNS Zone VNet Links

Monitoring (4):
  Application Insights, Log Analytics Workspace
  Auto-scaling settings, Workbooks

**Total**: 81 resources in infoasst-dev2 + EVAChatDev2Rg
**Monthly Cost**: ~$500-700 (production-grade with full private endpoints)
```

### Sandbox (Target - 12 resources)
```
[REUSE] infoasst-aoai-dev2 (Azure OpenAI)
marco-sandbox-search (Cognitive Search Basic)
marco-sandbox-cosmos (Cosmos DB Serverless)
marcosandboxstore (Storage Standard_LRS)
  ?? PUBLIC endpoints with firewall rules
marco-sandbox-backend (Web App B1)
marco-sandbox-enrichment (Web App B1)
marco-sandbox-function (Function App Consumption)
[NO VNet - public endpoints only]
marco-sandbox-acr (Container Registry Basic)
marco-sandbox-kv (Key Vault Standard)
[REUSE] infoasst-docint-dev2 (Document Intelligence)
```

---

## Key Decisions & Justifications

### Decision 1: Public Endpoints
**Rationale**: 
- Dev2 has 14 private endpoints ($20-50/month each) + VNet infrastructure ($100+/month)
- Public endpoints with IP firewall rules sufficient for personal dev/test
- Pending policy confirmation from infrastructure team

**Risk**: If network policy requires private endpoints, fallback to minimal VNet with single PE

### Decision 2: Reuse Azure OpenAI
**Rationale**:
- OpenAI most expensive component (~$200/month for dedicated instance)
- Dev2 instance (infoasst-aoai-dev2) has gpt-4o + dev2-text-embedding deployments
- Sharing reduces total org cost, no impact on dev2 quota

**Risk**: If dev2 OpenAI becomes inaccessible, deploy new gpt-4o-mini instance ($50/month)

### Decision 3: Basic Search Tier
**Rationale**:
- Dev2 uses Standard S1 ($250/month) for production-grade performance
- Basic tier ($75/month) sufficient for PoC (<100 documents, lower QPS)
- Can upgrade to Standard if performance issues

**Risk**: Basic limited to 2GB index size, no semantic ranker

### Decision 4: Serverless Cosmos DB
**Rationale**:
- Dev2 uses Session-level ($25+/month minimum)
- Serverless pay-per-use ideal for intermittent dev/test
- Estimated <$10/month for low traffic

**Risk**: Cold start latency (5-10 seconds after idle), acceptable for dev/test

### Decision 5: B1 Web Apps
**Rationale**:
- Dev2 uses P1V2 ($73/month per app) for production SLA
- B1 ($13/month) adequate for personal use, no uptime SLA
- 1.75GB RAM sufficient for Python/Quart backend

**Risk**: Performance degradation under load, acceptable for single-user PoC

---

## Success Criteria

### Functional Requirements
- [ ] **RAG Pipeline**: Document upload ? OCR ? chunking ? embedding ? indexing working end-to-end
- [ ] **Chat Interface**: Ask questions, receive answers with citations from indexed documents
- [ ] **Search**: Hybrid vector+keyword search returning relevant results
- [ ] **Authentication**: Azure AD login working for marco.presta@hrsdc-rhdcc.gc.ca

### Performance Requirements
- [ ] **Chat Response Time**: <10 seconds for typical queries (vs. <3 seconds in dev2)
- [ ] **Document Processing**: <5 minutes for 10-page PDF (vs. <2 minutes in dev2)
- [ ] **Search Latency**: <2 seconds for keyword search (vs. <500ms in dev2)

### Cost Requirements
- [ ] **Monthly Spend**: <$150 CAD/month measured via Cost Management
- [ ] **Cost Alerts**: Configured at $100 (warning) and $150 (critical) thresholds
- [ ] **Tag Compliance**: All resources tagged with owner, environment, project, cost_center

### Operational Requirements
- [ ] **Zero Impact**: Dev2 environment unaffected (no shared resource contention)
- [ ] **Terraform State**: State file stored in Azure Blob with lock
- [ ] **Secrets Management**: All secrets in Key Vault, no hardcoded credentials
- [ ] **Monitoring**: Application Insights telemetry enabled, basic health checks

---

## Constraints

### Hard Constraints (Cannot Change)
1. **Subscription**: Must use EsDAICoESub (ESDC tenant subscription)
2. **Region**: Canada East (data residency requirement)
3. **Authentication**: Azure AD with marco.presta@hrsdc-rhdcc.gc.ca
4. **Tagging**: Required tags per ESDC policy (owner, environment, project, ssc_cbrid, cost_center)
5. **Budget**: Hard cap at $150/month (auto-shutdown if exceeded)

### Soft Constraints (Can Negotiate)
1. **Network Policy**: Public endpoints preferred, can add VNet if required
2. **APIM Access**: Preferred to reuse, can skip if unavailable
3. **Timeline**: Target February 14, flexible by 1 week
4. **Performance**: Lower SLA acceptable for dev/test use case

---

## Deployment Timeline

### Phase 1: Pre-Deployment (Feb 3-4) ? COMPLETE
- ? Inventory collection: Enhanced script validated, 1,383 resources analyzed
- ? Dev2 analysis: 81 resources documented (was 63 estimate)
- ? Reusability scoring: 446 resources identified for potential reuse
- ? APIM readiness: 132 API-exposed resources catalogued
- ? Cost optimization: 437 FinOps opportunities identified
- ? Evidence: VALIDATION-COMPLETE-20260203.md, SANDBOX-BLUEPRINT-rg-sandbox-marco.md
- ? Terraform config preparation: Architecture patterns validated from dev2

### Phase 2: Infrastructure Team Actions (Feb 5-7)
- rg-sandbox-marco provisioned
- Contributor role assigned to marco.presta@hrsdc-rhdcc.gc.ca
- Network policy clarification received

### Phase 3: Deployment (Feb 10-12)
- Terraform init + plan + apply
- Resource validation
- Configuration deployment (backend.env, function settings)

### Phase 4: Validation (Feb 12-13)
- Functional testing (upload, search, chat)
- Performance benchmarking
- Cost validation

### Phase 5: Cost Monitoring (Feb 14+)
- Cost alerts configured
- Weekly cost review
- Optimization if needed

---

## Next Steps

### Immediate Actions (Today - Feb 3)
1. **Execute Phase 1.1**: Run inventory collection commands (see PLAN.md)
2. **Write Terraform Config**: Create marco-sandbox.tfvars
3. **Write Backend Config**: Create backend-marco-sandbox.env.template
4. **Send Email**: Infrastructure team request with 3 questions

### Waiting On
- Infrastructure team response (network policy, APIM, OpenAI confirmation)
- rg-sandbox-marco provisioned
- Contributor role assignment

### Blockers
- **Deployment blocked** until Contributor role assigned to rg-sandbox-marco
- **Configuration decisions pending** network policy clarification

---

## Documentation

- **PLAN.md**: Detailed 5-phase execution plan with commands and validation steps
- **SEEDING-SANDBOX-PROCESS.md**: Complete guide to populating marco-sandbox with initial RBAC, example questions, and containers (foundation for self-service sandbox feature)
- **inventory/**: Pre-deployment inventory collection outputs (Phase 1.1)
- **terraform/**: Terraform configuration files (Phase 1.3)
- **logs/**: Deployment logs and troubleshooting artifacts
- **tests/**: Validation test scripts and results (Phase 4)
- **archive/**: Superseded documentation and scripts (housekeeping Feb 4, 2026)

---

## Project Housekeeping

**Last Housekeeping**: February 4, 2026

### Archived Content
- **superseded-status/**: 8 status documents replaced by current docs
- **planning-docs/**: 8 planning documents (work executed)
- **old-logs/**: 7 deployment logs + test evidence
- **transient-scripts/**: 9 deployment/extraction scripts (superseded)

**Archive Index**: See [archive/ARCHIVE-INDEX.md](./archive/ARCHIVE-INDEX.md) for full inventory

### Active Documentation
- **Status**: DEPLOYMENT-STATUS-CURRENT.md (live status)
- **Inventory**: RESOURCE-INVENTORY-20260204.md (17 resources with SKUs)
- **Audit**: AUDIT-REPORT-20260204.md (comprehensive findings)
- **Architecture**: ARCHITECTURE-DIAGRAM.md
- **Cost Control**: COST-CONTROL-README.md, COST-CONTROL-STATUS.md
- **Seeding Process**: SEEDING-SANDBOX-PROCESS.md (data population guide for self-service feature)

### Housekeeping Policy
- **Status files**: Archive when superseded by new version
- **Planning docs**: Archive when work executed
- **Logs**: Archive deployment logs after successful completion
- **Scripts**: Archive transient/experimental scripts when replaced
- **Retention**: All archived content kept indefinitely for audit trail

---

## Contact & Escalation

**Project Owner**: Marco Presta  
**Email**: marco.presta@hrsdc-rhdcc.gc.ca  
**Team**: ESDC AICOE  
**Escalation**: Infrastructure team for RG provisioning, Azure admins for quota issues

**Related Projects**:
- Dev2 Environment: infoasst-dev2 (source architecture)
- EVA-JP-v1.2: Main EVA codebase
- PubSec-Info-Assistant: Upstream template

---

**Last Updated**: February 4, 2026  
**Status**: Phase 3 50% complete, awaiting IT permission for Cost Management exports
