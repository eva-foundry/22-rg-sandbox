# Sandbox Cost Control Guide

**Created**: February 3, 2026  
**Owner**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Monthly Cost**: $197/month (without controls) → $158/month (with scheduling)

---

## Quick Reference

```powershell
# STOP everything NOW (emergency)
.\Stop-Sandbox.ps1 -Force

# START everything NOW
.\Start-Sandbox.ps1

# Set up automatic start/stop (Mon-Fri 8AM-6PM)
.\Schedule-Sandbox.ps1

# Remove automatic schedule
.\Schedule-Sandbox.ps1 -Remove
```

---

## Cost Breakdown (Monthly)

### Base Costs (February 2026)

| Resource | Monthly Cost | Can Stop? | Savings |
|----------|-------------|-----------|---------|
| **App Service Plan - Backend** | $13 | ✅ Yes | $13 |
| **App Service Plan - Enrichment** | $13 | ✅ Yes | $13 |
| **App Service Plan - Functions** | $3 | ✅ Yes | $3 |
| **APIM Gateway** | $50 | ❌ No | $0 |
| **Azure Search** | $75 | ❌ No | $0 |
| **Cosmos DB** | $8 | ❌ No | $0 |
| **Storage Account** | $5 | ❌ No | $0 |
| **FinOps Storage** | $15 | ❌ No | $0 |
| **FinOps Data Factory** | $10 | ❌ No | $0 |
| **Other (ACR, Key Vault, etc.)** | $5 | ❌ No | $0 |
| **TOTAL** | **$197/month** | | **$29/month** |

### With Business Hours Schedule (Mon-Fri 8AM-6PM)

- **Running Time**: 50 hours/week (30%)
- **Stopped Time**: 118 hours/week (70%)
- **Compute Savings**: $29/month × 70% = **$20/month**
- **New Total**: **$177/month** (10% reduction)

### With Aggressive Schedule (Weekdays Only)

If you start/stop manually based on actual usage:

- **Active Development**: 20 hours/week (12%)
- **Stopped**: 148 hours/week (88%)
- **Compute Savings**: $29/month × 88% = **$26/month**
- **New Total**: **$171/month** (13% reduction)

---

## Scripts Overview

### 1. Stop-Sandbox.ps1 (Kill Switch)

**Purpose**: Stop all compute resources immediately to minimize costs.

**What it stops**:
- ✅ marco-sandbox-asp-backend (App Service Plan)
- ✅ marco-sandbox-asp-enrichment (App Service Plan)
- ✅ marco-sandbox-asp-func (App Service Plan)
- ✅ marco-sandbox-backend (Web App)
- ✅ marco-sandbox-enrichment (Web App)
- ✅ marco-sandbox-func (Function App)

**What stays running** (unavoidable costs):
- ❌ APIM Gateway ($50/month - charged even when stopped)
- ❌ Azure Search ($75/month - minimal idle cost, can't stop)
- ❌ Cosmos DB ($8/month - minimal idle cost)
- ❌ Storage ($5/month - always charged)

**Usage**:
```powershell
# Interactive stop with confirmation
.\Stop-Sandbox.ps1

# Emergency stop (no prompts)
.\Stop-Sandbox.ps1 -Force

# Preview what would be stopped
.\Stop-Sandbox.ps1 -WhatIf
```

**Output**:
```
=== RESOURCES TO STOP ===
  App Service Plan: marco-sandbox-asp-backend
    SKU: B1 (Basic)
    Current Status: Ready
    Monthly Cost: $13/month

TOTAL SAVINGS WHEN STOPPED:
  Monthly: $29/month
  Hourly: $0.04/hour
```

### 2. Start-Sandbox.ps1 (Start All)

**Purpose**: Start all sandbox resources quickly.

**Startup Time**: 2-3 minutes (typical)

**What it starts**:
- ✅ All 3 App Service Plans
- ✅ All 2 Web Apps
- ✅ All 1 Function App

**Usage**:
```powershell
# Start everything
.\Start-Sandbox.ps1

# Start and wait for health checks
.\Start-Sandbox.ps1 -HealthCheck

# Preview
.\Start-Sandbox.ps1 -WhatIf
```

**Output**:
```
=== RESOURCES TO START ===
  marco-sandbox-backend
    Current State: Stopped

[ACTION] Starting all apps...
  [PASS] marco-sandbox-backend started

Startup Time: 32.4 seconds

NEXT STEPS:
  1. Wait 2-3 minutes for full warmup
  2. Backend: https://marco-sandbox-backend.azurewebsites.net/health
```

### 3. Schedule-Sandbox.ps1 (Automatic Start/Stop)

**Purpose**: Set up Windows Task Scheduler jobs for automatic start/stop.

**Default Schedule**:
- **START**: Monday-Friday at 8:00 AM ET
- **STOP**: Monday-Friday at 6:00 PM ET
- **Weekend**: Stopped (Sat-Sun)

**Requirements**:
- Administrator privileges
- Windows Task Scheduler
- Scripts must be in fixed location (don't move folder)

**Usage**:
```powershell
# Set up default schedule (8AM-6PM Mon-Fri)
.\Schedule-Sandbox.ps1

# Custom hours
.\Schedule-Sandbox.ps1 -StartTime "07:00" -StopTime "19:00"

# Run 7 days/week
.\Schedule-Sandbox.ps1 -WorkDaysOnly:$false

# Preview
.\Schedule-Sandbox.ps1 -WhatIf

# Remove schedule
.\Schedule-Sandbox.ps1 -Remove
```

**Output**:
```
=== PROPOSED SCHEDULE ===
START TIME: 08:00
STOP TIME: 18:00
WORK DAYS ONLY: True

Schedule: Monday - Friday
  08:00 - START (apps come online)
  18:00 - STOP (apps shut down)
  Weekend: Stopped all weekend

Running Time: ~50 hours/week (30%)
Stopped Time: ~118 hours/week (70%)

Cost Savings:
  Without schedule: $39/month (24/7 running)
  With schedule: $12/month (business hours only)
  SAVINGS: $27/month (70%)
```

---

## Cost Optimization Strategies

### Strategy 1: Business Hours Only (Recommended)

**Setup**:
```powershell
.\Schedule-Sandbox.ps1
```

**Benefits**:
- ✅ Automatic - set it and forget it
- ✅ Consistent schedule
- ✅ Weekend savings

**Savings**: $20/month (10% reduction)

**Best For**: Regular development schedule (Mon-Fri)

### Strategy 2: Manual Start/Stop (Maximum Savings)

**Setup**: Use scripts manually when needed

**Workflow**:
```powershell
# Morning: Start for work session
.\Start-Sandbox.ps1

# Evening: Stop when done
.\Stop-Sandbox.ps1 -Force
```

**Benefits**:
- ✅ Maximum savings (88% stopped)
- ✅ Pay only for actual usage

**Savings**: $26/month (13% reduction)

**Best For**: Irregular development schedule, sporadic usage

### Strategy 3: Weekend Shutdown Only

**Setup**:
```powershell
# Manual schedule for Friday evening
.\Stop-Sandbox.ps1 -Force

# Manual start Monday morning
.\Start-Sandbox.ps1
```

**Benefits**:
- ✅ Minimal management
- ✅ Weekend savings (48 hours/week)

**Savings**: $8/month (4% reduction)

**Best For**: Continuous weekday development

### Strategy 4: Keep APIM Running, Stop Compute

**Setup**: Stop compute but keep APIM for API access

**Rationale**:
- APIM ($50/month) is charged regardless of state
- Compute ($29/month) can be stopped
- Keep APIM for testing without full compute

**Workflow**:
```powershell
# Stop compute (saves $29/month potential)
.\Stop-Sandbox.ps1 -Force

# APIM stays running (cost unavoidable)
```

**Best For**: API design/testing without backend execution

---

## Cost Monitoring

### Daily Cost Tracking

**FinOps Hub** (Phase 3 - deploying):
- Storage: marcosandboxfinopshub
- Data Factory: marco-sandbox-finops-adf
- Cost Export: marco-sandbox-costs-daily

**Once deployed**, you'll get:
- Daily cost exports (CSV format)
- Resource-level cost breakdown
- Trend analysis

### Manual Cost Check

```powershell
# Check current month costs
az consumption usage list \
    --start-date "2026-02-01" \
    --end-date "2026-02-28" \
    --query "[?resourceGroup=='EsDAICoE-Sandbox'].{Resource:instanceName, Cost:pretaxCost}" \
    -o table
```

### Cost Alerts (Recommended Setup)

Create alerts in Azure Portal:
1. **Alert 1**: Daily cost > $10
2. **Alert 2**: Monthly projected > $220
3. **Alert 3**: App Service Plan running > 16 hours/day

---

## Troubleshooting

### Scripts Not Working

**Issue**: "Access denied" or "Resource not found"

**Solution**:
```powershell
# Verify Azure CLI login
az account show

# Set correct subscription
az account set --subscription "EsDAICoESub"

# Verify resource group exists
az group show --name "EsDAICoE-Sandbox"
```

### Scheduled Tasks Not Running

**Issue**: Tasks exist but don't execute

**Solution**:
```powershell
# Check task status
Get-ScheduledTask -TaskName "Sandbox-*" | Select-Object TaskName, State, LastRunTime, NextRunTime

# View task history
Get-ScheduledTask -TaskName "Sandbox-AutoStart" | Get-ScheduledTaskInfo

# Run task manually to test
Start-ScheduledTask -TaskName "Sandbox-AutoStart"
```

### Apps Not Starting

**Issue**: Start script completes but apps still stopped

**Solution**:
```powershell
# Check App Service Plan state
az appservice plan show --name "marco-sandbox-asp-backend" --resource-group "EsDAICoE-Sandbox" --query "{name:name, status:status, state:properties.status}"

# Force start individual app
az webapp start --name "marco-sandbox-backend" --resource-group "EsDAICoE-Sandbox"

# Check for deployment issues
az webapp log tail --name "marco-sandbox-backend" --resource-group "EsDAICoE-Sandbox"
```

---

## Best Practices

### ✅ DO

- **Use scheduled start/stop** for regular work hours
- **Stop manually** when leaving for vacation/long weekends
- **Check costs weekly** via Azure Portal
- **Set up cost alerts** for unexpected charges
- **Keep scripts in fixed location** (don't move folder)
- **Test scripts** before relying on scheduling

### ❌ DON'T

- **Don't delete APIM** (it's expensive to recreate, $50/month sunk cost)
- **Don't stop Search/Cosmos** (minimal idle cost, can't stop anyway)
- **Don't over-optimize** (manual start/stop fatigue vs. $5/month savings)
- **Don't forget to start** before demos/testing
- **Don't schedule during peak work hours** (8AM-6PM is safe)

---

## Comparison: Sandbox vs. Production

| Aspect | Sandbox | Production (infoasst-dev2) |
|--------|---------|---------------------------|
| **Base Cost** | $197/month | $400+/month |
| **Stoppable Compute** | $29/month (15%) | $150/month (38%) |
| **Unavoidable Costs** | $168/month (85%) | $250/month (62%) |
| **Stop/Start Impact** | Low (15% savings) | High (38% savings) |
| **Recommendation** | Scheduled Mon-Fri | Always-on |

**Insight**: Production has higher compute % (38% vs. 15%), so stop/start has bigger impact there. Sandbox is mostly unavoidable infrastructure costs (APIM, Search, Storage).

---

## Future Cost Optimizations

### When FinOps Hub Deploys (Phase 3)

You'll gain:
- **Daily cost exports** (automatic CSV files)
- **Trend analysis** (Power BI dashboards)
- **Resource-level tracking** (which service costs most)
- **Budget forecasting** (predict next month)

### Azure Advisor Recommendations

Check monthly:
```powershell
az advisor recommendation list --query "[?category=='Cost'].{Title:shortDescription.problem, Savings:extendedProperties.savingsAmount, Resource:impactedValue}" -o table
```

### Right-Sizing Opportunities

**Current**: B1 App Service Plans ($13/month each)

**Alternatives**:
- **F1 (Free)**: $0/month (limited to 60 min/day)
- **D1 (Shared)**: $10/month per plan
- **S1 (Standard)**: $75/month (if need more power)

**Recommendation**: Keep B1 for sandbox (good balance of cost/features)

---

## Summary

**Without Controls**: $197/month
**With Business Hours Schedule**: $177/month (10% reduction)
**With Manual Start/Stop**: $171/month (13% reduction)

**Recommended Strategy**: Use `Schedule-Sandbox.ps1` for Mon-Fri 8AM-6PM automatic control.

**Emergency Actions**:
- Weekend getaway: `.\Stop-Sandbox.ps1 -Force`
- Quick start: `.\Start-Sandbox.ps1`
- Remove schedule: `.\Schedule-Sandbox.ps1 -Remove`

---

**Last Updated**: February 3, 2026  
**Scripts Location**: `I:\eva-foundation\22-rg-sandbox\`
