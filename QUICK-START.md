# Project 22 - Quick Reference Card

**Status**: READY TO DEPLOY ✅  
**Target**: EsDAICoE-Sandbox (Canada Central)  
**Access**: Owner role active (expires April 17, 2026)  
**Deployment Option**: Option A - Full Observability (APIM + FinOps)  
**Budget**: $237/month  
**Method**: Azure CLI

---

## Deploy in 3 Commands (Option A - Full Observability)

```powershell
cd I:\eva-foundation\22-rg-sandbox
.\Deploy-Full-Observability.ps1 -WhatIf  # Preview all 3 phases
.\Deploy-Full-Observability.ps1 -Phase All  # Deploy everything
```

**Time**: 35-55 minutes (Base 15-20min + APIM 15-20min + FinOps 5-10min)

### Alternative: Deploy Base Only ($122/month)

```powershell
.\Deploy-Sandbox-AzCLI.ps1 -WhatIf  # Preview base system
.\Deploy-Sandbox-AzCLI.ps1           # Deploy 12 resources
```

---

## What Gets Deployed - Full Observability

### Phase 1: Base RAG System ($122/month)

| Resource | Cost/Month |
|----------|------------|
| Cognitive Search (Basic) | $75 |
| Cosmos DB (Serverless) | $10 |
| Storage Account | $5 |
| 2x Web Apps (B1) | $26 |
| Function App (Consumption) | $5 |
| Container Registry | $5 |
| Key Vault + Insights | $5 |
| **SUBTOTAL** | **$122** |

### Phase 2: APIM Gateway (+$50/month)

| Resource | Cost/Month |
|----------|------------|
| API Management (Developer SKU) | $50 |
| **SUBTOTAL** | **$50** |

**Features**: Rate limiting, JWT validation, cost attribution headers, Application Insights logging

### Phase 3: FinOps Hub (+$65/month)

| Resource | Cost/Month |
|----------|------------|
| Storage Account (Data Lake) | $15 |
| Data Factory (ingestion) | $20 |
| Log Analytics | $30 |
| **SUBTOTAL** | **$65** |

**Features**: Daily cost exports, 13-month history, Power BI dashboards, custom metrics

### Total: $237/month

**Reused** (FREE): Azure OpenAI (infoasst-aoai-dev2), Document Intelligence (infoasst-docint-dev2)

---

## Post-Deployment Checklist

- [ ] Configure Azure OpenAI connection (infoasst-aoai-dev2)
- [ ] Create Search index (hybrid vector+keyword)
- [ ] Deploy backend code to Web Apps
- [ ] Deploy function code to Function App
- [ ] Set environment variables
- [ ] Test document upload → pipeline → search → chat

---

## Key Files

| File | Purpose |
|------|---------|
| `Deploy-Full-Observability.ps1` | **Master deployment orchestrator** |
| `Deploy-Sandbox-AzCLI.ps1` | Phase 1: Base RAG system |
| `Deploy-APIM.ps1` | Phase 2: API Management |
| `Deploy-FinOpsHub-Sandbox.ps1` | Phase 3: FinOps Hub |
| `Configure-CostTracking.ps1` | Post-deployment cost tracking setup |
| `APIM-FINOPS-INTEGRATION-PLAN.md` | Architecture & integration guide |
| `DEPLOYMENT-GUIDE.md` | Step-by-step instructions |
| `README.md` | Architecture overview |
| `OPERATIONAL-RUNBOOK.md` | Daily/weekly/monthly operations |

---

## Emergency Commands

**Check deployment status:**
```powershell
az resource list --resource-group "EsDAICoE-Sandbox" --query "length([])"
# Should show 12+ resources
```

**Monitor costs:**
```powershell
az consumption usage list --query "[?contains(instanceId, 'EsDAICoE-Sandbox')]"
```

**Cleanup specific resource:**
```powershell
az resource delete --ids "/subscriptions/.../resourceGroups/EsDAICoE-Sandbox/providers/.../resourceName"
```

---

## Support

- **Documentation**: `DEPLOYMENT-GUIDE.md`
- **Deployment log**: `deployment-log-*.json`
- **Contact**: marco.presta@hrsdc-rhdcc.gc.ca
- **Copilot Instructions**: `.github/copilot-instructions.md`

---

**Ready to deploy?** Run `.\Deploy-Sandbox-AzCLI.ps1 -WhatIf` to start!
