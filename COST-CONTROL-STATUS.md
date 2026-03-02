# Sandbox Cost Control - Quick Start Guide

**Date**: February 3, 2026  
**Status**: ✅ Scripts Created & Tested  
**Next**: Set up automatic scheduling (requires Admin)

---

## ✅ COMPLETED

### 1. Kill Switch - Stop-Sandbox.ps1
- **Status**: ✅ Created and tested with `-WhatIf`
- **Savings**: $29/month potential (when stopped)
- **What it stops**: 3 App Service Plans (Backend, Enrichment, Functions)
- **Usage**: `.\Stop-Sandbox.ps1 -Force`

**Test Results**:
```
=== RESOURCES TO STOP ===
  App Service Plan: marco-sandbox-asp-backend ($13/month)
  App Service Plan: marco-sandbox-asp-enrichment ($13/month)
  App Service Plan: marco-sandbox-asp-func ($3/month)

TOTAL SAVINGS: $29/month
```

### 2. Start All - Start-Sandbox.ps1
- **Status**: ✅ Created
- **Startup Time**: 2-3 minutes
- **What it starts**: All 3 App Service Plans + Web Apps + Functions
- **Usage**: `.\Start-Sandbox.ps1`
- **Health Check**: `.\Start-Sandbox.ps1 -HealthCheck`

### 3. Cost Monitoring - Monitor-DailyCosts.ps1
- **Status**: ✅ Created and tested
- **Thresholds**: $10/day, $220/month projected
- **Alert File**: Creates `COST-ALERT-{date}.txt` when exceeded
- **Usage**: `.\Monitor-DailyCosts.ps1`
- **Schedule**: Can run daily via Task Scheduler

**Features**:
- Checks current daily spending
- Calculates month-to-date total
- Projects monthly costs based on average
- Shows top 5 expensive resources
- Creates alert file if thresholds exceeded

### 4. Automated Budgets - Setup-CostAlerts.ps1
- **Status**: ⚠️ Partially working (Azure API limitations)
- **Alternative**: Use Azure Portal for budget creation
- **Manual Setup**: https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/budgets
- **Recommended Budget**: CAD $220/month for EsDAICoE-Sandbox

---

## ⏳ PENDING: Automatic Scheduling

### 5. Schedule-Sandbox.ps1
- **Status**: ⏳ Requires Administrator privileges
- **Default Schedule**: Mon-Fri 8AM-6PM
- **Estimated Savings**: $20/month (70% of compute costs stopped)

**To Set Up** (requires Admin PowerShell):

1. **Right-click PowerShell** → "Run as Administrator"
2. **Navigate**: `cd I:\eva-foundation\22-rg-sandbox`
3. **Run**: `.\Schedule-Sandbox.ps1`
4. **Confirm**: Type 'YES' when prompted

**What it creates**:
- `Sandbox-AutoStart` task (Mon-Fri 8:00 AM)
- `Sandbox-AutoStop` task (Mon-Fri 6:00 PM)

**Manual Alternative** (if script fails):
1. Press `Win+R`, type `taskschd.msc`, press Enter
2. Create Task → Name: `Sandbox-AutoStart`
3. Trigger: Daily at 8:00 AM, weekdays only
4. Action: Start PowerShell
   - Program: `PowerShell.exe`
   - Arguments: `-NoProfile -ExecutionPolicy Bypass -File "I:\eva-foundation\22-rg-sandbox\Start-Sandbox.ps1"`
5. Repeat for `Sandbox-AutoStop` at 6:00 PM with `Stop-Sandbox.ps1 -Force`

---

## 💰 COST IMPACT SUMMARY

### Current Baseline (Once APIM + FinOps Deploy)
- **Phase 1 (Base RAG)**: $122/month
- **Phase 2 (APIM)**: $50/month
- **Phase 3 (FinOps)**: $25/month
- **TOTAL**: $197/month

### With Cost Controls

| Strategy | Savings | New Total | Reduction |
|----------|---------|-----------|-----------|
| **No controls** | $0 | $197/month | 0% |
| **Weekend shutdown** | $8/month | $189/month | 4% |
| **Business hours (8AM-6PM Mon-Fri)** | $20/month | $177/month | 10% |
| **Manual start/stop (as needed)** | $26/month | $171/month | 13% |

### What CAN'T Be Stopped (85% of costs)
- **APIM Gateway**: $50/month (charged even when stopped)
- **Azure Search**: $75/month (can't stop, minimal idle cost)
- **Cosmos DB**: $8/month (can't stop, minimal idle cost)
- **Storage**: $5/month (always charged)
- **FinOps Hub**: $25/month (Storage + Data Factory)
- **Other**: $5/month (Key Vault, ACR, App Insights)
- **TOTAL**: $168/month unavoidable

### What CAN Be Stopped (15% of costs)
- **App Service Plans (3x)**: $29/month
- **Savings**: 70% when stopped = $20/month with business hours schedule

---

## 🚀 DAILY OPERATIONS

### Morning Workflow (Manual)
```powershell
cd I:\eva-foundation\22-rg-sandbox
.\Start-Sandbox.ps1
# Wait 2-3 minutes for apps to warm up
```

### Evening Workflow (Manual)
```powershell
cd I:\eva-foundation\22-rg-sandbox
.\Stop-Sandbox.ps1 -Force
```

### Weekly Cost Check
```powershell
cd I:\eva-foundation\22-rg-sandbox
.\Monitor-DailyCosts.ps1
# Review output + check for COST-ALERT files
```

### Emergency Stop
```powershell
.\Stop-Sandbox.ps1 -Force
# Use when leaving for vacation, long weekend, etc.
```

---

## 📊 MONITORING & ALERTS

### Automated Daily Monitoring
**Setup Task Scheduler** (once):
1. Open Task Scheduler (`taskschd.msc`)
2. Create Task: `Sandbox-CostCheck`
3. Trigger: Daily at 9:00 AM
4. Action: `PowerShell.exe -File "I:\eva-foundation\22-rg-sandbox\Monitor-DailyCosts.ps1"`

**What it does**:
- Runs every morning at 9 AM
- Checks yesterday's costs
- Creates alert file if threshold exceeded
- You'll see `COST-ALERT-{date}.txt` in folder when costs are high

### Manual Checks
```powershell
# Check current costs
.\Monitor-DailyCosts.ps1

# Preview what would be stopped
.\Stop-Sandbox.ps1 -WhatIf

# Check what's currently running
az resource list --resource-group "EsDAICoE-Sandbox" --query "[].{Name:name, Type:type, State:properties.state}" -o table
```

### Azure Portal Dashboards
- **Cost Analysis**: https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/costanalysis
- **Budgets**: https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/budgets
- **Resource Health**: https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups

---

## 🎯 RECOMMENDED SETUP

**For Your Scenario** (Owner until April 17, 2026):

1. ✅ **DONE**: Scripts created and tested
2. ⏳ **NEXT**: Set up automatic Mon-Fri 8AM-6PM schedule
   - Saves $20/month
   - Hands-free operation
   - Weekend automatic shutdown
3. 📅 **OPTIONAL**: Add daily cost monitoring task
   - Runs every morning
   - Alerts if costs spike
4. 🔔 **OPTIONAL**: Azure Portal budget (manual setup)
   - Budget: CAD $220/month
   - Alerts at: 80%, 90%, 100%

**Time Investment**:
- Initial setup: 15 minutes (one-time)
- Daily management: 0 minutes (automated)
- Weekly review: 2 minutes (optional cost check)

**ROI**:
- Setup time: 15 minutes
- Monthly savings: $20
- Annual savings: $240
- **Value**: $960/hour equivalent

---

## 📁 FILES CREATED

All files in: `I:\eva-foundation\22-rg-sandbox\`

| File | Purpose | Usage |
|------|---------|-------|
| **Stop-Sandbox.ps1** | Emergency stop all compute | `.\Stop-Sandbox.ps1 -Force` |
| **Start-Sandbox.ps1** | Quick start all resources | `.\Start-Sandbox.ps1` |
| **Schedule-Sandbox.ps1** | Set up automatic start/stop | Requires Admin |
| **Monitor-DailyCosts.ps1** | Daily cost monitoring | `.\Monitor-DailyCosts.ps1` |
| **Setup-CostAlerts.ps1** | Azure budget creation | Portal preferred |
| **COST-CONTROL-README.md** | Full documentation | Reference guide |
| **ARCHITECTURE-DIAGRAM.md** | System architecture | Updated with actual names |

---

## 🔧 TROUBLESHOOTING

### "Access Denied" Errors
```powershell
# Verify Azure login
az account show

# Set correct subscription
az account set --subscription "EsDAICoESub"
```

### Scripts Not Stopping Resources
```powershell
# Check current state
az appservice plan list --resource-group "EsDAICoE-Sandbox" --query "[].{Name:name, State:properties.status}" -o table

# Force stop individual app
az webapp stop --name "marco-sandbox-backend" --resource-group "EsDAICoE-Sandbox"
```

### Cost Monitoring Returns No Data
- **Reason**: Azure Cost Management has 24-48 hour delay
- **Solution**: Check again tomorrow, costs may not be available yet

---

## 🎉 NEXT STEPS

**Immediate** (today):
1. ⏳ Set up automatic scheduling (requires Admin PowerShell)
   - Right-click PowerShell → Run as Administrator
   - `cd I:\eva-foundation\22-rg-sandbox`
   - `.\Schedule-Sandbox.ps1`

**This Week**:
2. ⏳ Create Azure budget in Portal (manual)
   - Go to: https://portal.azure.com/#blade/Microsoft_Azure_CostManagement/Menu/budgets
   - Budget: CAD $220/month
   - Scope: EsDAICoE-Sandbox resource group
   - Alerts: 80%, 90%, 100%

**Optional** (if you want daily monitoring):
3. ⏳ Set up daily cost check task
   - Open Task Scheduler
   - Create task to run `Monitor-DailyCosts.ps1` every morning

---

**Last Updated**: February 3, 2026 3:30 PM  
**Status**: Ready for automatic scheduling setup
