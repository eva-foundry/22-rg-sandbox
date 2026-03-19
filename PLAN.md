<!-- eva-primed-plan -->

## EVA Ecosystem Tools

- Data model: GET https://msub-eva-data-model.victoriousgrass-30debbd3.canadacentral.azurecontainerapps.io/model/projects/22-rg-sandbox
- 29-foundry agents: C:\eva-foundry\eva-foundation\29-foundry\agents\
- 48-eva-veritas audit: run audit_repo MCP tool

---

# Project Plan

<!-- veritas-normalized 2026-02-25 prefix=F22 source=README.md -->
<!-- RETIRED 2026-02-26 -- mission complete -->

## [RETIRED 2026-02-26] -- Infrastructure mission complete

**Status**: RETIRED -- all Azure sandbox resources established and handed off.

| Resource | Status | Owner project |
|---|---|---|
| marco-sandbox-apim (APIM Developer) | LIVE | 17-apim |
| Container Apps (brain-api, roles-api) | LIVE | 33-eva-brain-v2 |
| marcosandkv20260203 (Key Vault) | LIVE -- secrets empty | 17-apim (pending) |
| Cosmos DB (eva-foundation) | LIVE | 33-eva-brain-v2 |
| Azure AI Search | LIVE | 11-ms-infojp |
| App Insights | LIVE | all projects |

**KV secrets gap**: APIM eva-core subscription key NOT yet stored in KV.
Unblock WI-3 path: `az apim subscription list --resource-group rg-sandbox-marco --service-name marco-sandbox-apim` -> store primary key as secret `apim-eva-core-key` in marcosandkv20260203 -> set `VITE_APIM_SUBSCRIPTION_KEY` in 31-eva-faces portal-face .env.local

---

## Feature: Purpose [ID=F22-01]

## Feature: Frozen Scope (January 29, 2026) [ID=F22-02]

### Story: Architecture Decision: **Public Endpoints + Reuse Strategy** [ID=F22-02-001]

## Feature: Architecture Summary [ID=F22-03]

### Story: Resources to Deploy (12 total) [ID=F22-03-001]

## Feature: Prerequisites (Before Deployment) [ID=F22-04]

### Story: 1. Permissions Required [ID=F22-04-001]

- [ ] **Current**: Reader + Cost Management Contributor on EsDAICoESub [ID=F22-04-001-T01]
- [ ] **Needed**: Contributor role on rg-sandbox-marco (infrastructure team to assign) [ID=F22-04-001-T02]

### Story: 2. Infrastructure Team Confirmation [ID=F22-04-002]

### Story: 3. Pre-Deployment Inventory (Phase 1.1) [ID=F22-04-003]

- [ ] Azure OpenAI quota status [ID=F22-04-003-T01]
- [ ] APIM instance list [ID=F22-04-003-T02]
- [ ] Policy assignments on subscription [ID=F22-04-003-T03]
- [ ] OpenAI deployment names [ID=F22-04-003-T04]
- [ ] Cost allocation tags [ID=F22-04-003-T05]

## Feature: Reference Architecture (Dev2 ? Sandbox Mapping) [ID=F22-05]

### Story: Dev2 (Source - 81 resources, validated 2026-02-03) [ID=F22-05-001]

### Story: Sandbox (Target - 12 resources) [ID=F22-05-002]

## Feature: Key Decisions & Justifications [ID=F22-06]

### Story: Decision 1: Public Endpoints [ID=F22-06-001]

### Story: Decision 2: Reuse Azure OpenAI [ID=F22-06-002]

### Story: Decision 3: Basic Search Tier [ID=F22-06-003]

### Story: Decision 4: Serverless Cosmos DB [ID=F22-06-004]

### Story: Decision 5: B1 Web Apps [ID=F22-06-005]

## Feature: Success Criteria [ID=F22-07]

### Story: Functional Requirements [ID=F22-07-001]

- [ ] **RAG Pipeline**: Document upload ? OCR ? chunking ? embedding ? indexing working end-to-end [ID=F22-07-001-T01]
- [ ] **Chat Interface**: Ask questions, receive answers with citations from indexed documents [ID=F22-07-001-T02]
- [ ] **Search**: Hybrid vector+keyword search returning relevant results [ID=F22-07-001-T03]
- [ ] **Authentication**: Azure AD login working for marco.presta@hrsdc-rhdcc.gc.ca [ID=F22-07-001-T04]

### Story: Performance Requirements [ID=F22-07-002]

- [ ] **Chat Response Time**: <10 seconds for typical queries (vs. <3 seconds in dev2) [ID=F22-07-002-T01]
- [ ] **Document Processing**: <5 minutes for 10-page PDF (vs. <2 minutes in dev2) [ID=F22-07-002-T02]
- [ ] **Search Latency**: <2 seconds for keyword search (vs. <500ms in dev2) [ID=F22-07-002-T03]

### Story: Cost Requirements [ID=F22-07-003]

- [ ] **Monthly Spend**: <$150 CAD/month measured via Cost Management [ID=F22-07-003-T01]
- [ ] **Cost Alerts**: Configured at $100 (warning) and $150 (critical) thresholds [ID=F22-07-003-T02]
- [ ] **Tag Compliance**: All resources tagged with owner, environment, project, cost_center [ID=F22-07-003-T03]

### Story: Operational Requirements [ID=F22-07-004]

- [ ] **Zero Impact**: Dev2 environment unaffected (no shared resource contention) [ID=F22-07-004-T01]
- [ ] **Terraform State**: State file stored in Azure Blob with lock [ID=F22-07-004-T02]
- [ ] **Secrets Management**: All secrets in Key Vault, no hardcoded credentials [ID=F22-07-004-T03]
- [ ] **Monitoring**: Application Insights telemetry enabled, basic health checks [ID=F22-07-004-T04]

## Feature: Constraints [ID=F22-08]

### Story: Hard Constraints (Cannot Change) [ID=F22-08-001]

### Story: Soft Constraints (Can Negotiate) [ID=F22-08-002]

## Feature: Deployment Timeline [ID=F22-09]

### Story: Phase 1: Pre-Deployment (Feb 3-4) ? COMPLETE [ID=F22-09-001]

### Story: Phase 2: Infrastructure Team Actions (Feb 5-7) [ID=F22-09-002]

### Story: Phase 3: Deployment (Feb 10-12) [ID=F22-09-003]

### Story: Phase 4: Validation (Feb 12-13) [ID=F22-09-004]

### Story: Phase 5: Cost Monitoring (Feb 14+) [ID=F22-09-005]

## Feature: Next Steps [ID=F22-10]

### Story: Immediate Actions (Today - Feb 3) [ID=F22-10-001]

### Story: Waiting On [ID=F22-10-002]

### Story: Blockers [ID=F22-10-003]

## Feature: Documentation [ID=F22-11]

## Feature: Project Housekeeping [ID=F22-12]

### Story: Archived Content [ID=F22-12-001]

### Story: Active Documentation [ID=F22-12-002]

### Story: Housekeeping Policy [ID=F22-12-003]

## Feature: Contact & Escalation [ID=F22-13]
