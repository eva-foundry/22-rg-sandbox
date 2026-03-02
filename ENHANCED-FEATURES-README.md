# Enhanced Service Management & Vacation Calendar

**New Features**: Individual service control + vacation calendar integration

---

## 🎯 What's New

### 1. Individual Service Management (`Manage-SandboxServices.ps1`)
Interactive menu-driven tool to control services individually or in bulk.

**Features**:
- List all services with live status
- Start/stop/restart individual services
- Bulk operations on all compute services
- Service dependency tracking
- Health check integration
- Non-interactive mode for automation

**Usage**:
```powershell
# Interactive menu
.\Manage-SandboxServices.ps1

# Non-interactive mode
.\Manage-SandboxServices.ps1 -ServiceName "marco-sandbox-backend" -Action Start
.\Manage-SandboxServices.ps1 -ServiceName "marco-sandbox-enrichment" -Action Restart
.\Manage-SandboxServices.ps1 -ListOnly  # Quick status check
```

**Services Catalog**:
| Service | Type | Cost/Month | Stoppable | Description |
|---------|------|------------|-----------|-------------|
| marco-sandbox-backend | WebApp | $13 | ✅ | Backend API (Quart/Python) |
| marco-sandbox-enrichment | WebApp | $13 | ✅ | Enrichment Service (Flask) |
| marco-sandbox-func | FunctionApp | $3 | ✅ | Document Pipeline |
| marco-sandbox-search | SearchService | $75 | ❌ | Cognitive Search |
| marco-sandbox-cosmos | CosmosDB | $8 | ❌ | Database |
| marco-sandbox-apim | APIM | $50 | ❌ | API Gateway |
| marcosand20260203 | Storage | $5 | ❌ | Storage Account |

**Interactive Menu**:
```
========================================
  SANDBOX SERVICE MANAGEMENT
========================================

[SERVICES STATUS]

  [CTRL] marco-sandbox-backend          Running         $13/month
        Backend API (Quart/Python)
  [CTRL] marco-sandbox-enrichment       Running         $13/month
        Enrichment Service (Flask)
  [CTRL] marco-sandbox-func             Running         $3/month
        Document Pipeline Functions
  [AUTO] marco-sandbox-search           Succeeded       $75/month
        Cognitive Search (cannot stop)

[ACTIONS]
  1. Start ALL compute services
  2. Stop ALL compute services
  3. Restart ALL compute services
  4. Manage individual service
  5. Show service dependencies
  Q. Quit
```

---

### 2. Vacation Calendar (`vacation-calendar.txt`)
Skip auto-start/stop on holidays, vacations, and maintenance days.

**Format**:
```
YYYY-MM-DD | Type | Description

Types:
- HOLIDAY: Public holidays
- VACATION: Personal vacation days
- MAINTENANCE: Planned maintenance windows
- SKIP: Any other day to skip automation
```

**Pre-populated Holidays** (2026 Canada):
```
2026-01-01 | HOLIDAY | New Year's Day
2026-04-03 | HOLIDAY | Good Friday
2026-05-18 | HOLIDAY | Victoria Day
2026-07-01 | HOLIDAY | Canada Day
2026-09-07 | HOLIDAY | Labour Day
2026-10-12 | HOLIDAY | Thanksgiving
2026-12-25 | HOLIDAY | Christmas Day
2026-12-26 | HOLIDAY | Boxing Day
```

**Add Your Dates**:
```
# Personal vacation
2026-03-15 | VACATION | Spring break
2026-08-01 | VACATION | Summer vacation week 1
2026-08-08 | VACATION | Summer vacation week 2

# Maintenance windows
2026-06-15 | MAINTENANCE | Azure maintenance window
2026-11-01 | MAINTENANCE | OS updates

# Special events
2026-12-24 | SKIP | Early office closure
```

---

### 3. Vacation Calendar Checker (`Check-VacationCalendar.ps1`)
Helper script to validate if today is a skip day.

**Usage**:
```powershell
# Check today
.\Check-VacationCalendar.ps1

# Check specific date
.\Check-VacationCalendar.ps1 -CheckDate "2026-12-25"

# Exit codes:
# 0 = Normal working day (proceed)
# 1 = Vacation/Holiday (skip automation)
```

**Output Examples**:
```powershell
# Normal day
[INFO] 2026-02-03: Normal working day

# Holiday
========================================
  VACATION/HOLIDAY DETECTED
========================================
  Date: 2026-12-25
  Type: HOLIDAY
  Reason: Christmas Day

[ACTION] Auto-start/stop should be SKIPPED today
```

---

### 4. Updated Scheduler (`Schedule-Sandbox.ps1`)
Now integrates vacation calendar checking automatically.

**New Parameters**:
```powershell
.\Schedule-Sandbox.ps1 -SkipVacationCheck  # Disable calendar integration
```

**How It Works**:
1. Task Scheduler runs at scheduled time (e.g., 8:00 AM)
2. Checks `vacation-calendar.txt` for today's date
3. If holiday/vacation → **SKIP** operation (logs message)
4. If normal day → **PROCEED** with start/stop

**Task Command** (with vacation check):
```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "
  & 'I:\eva-foundation\22-rg-sandbox\Check-VacationCalendar.ps1'
  if ($LASTEXITCODE -eq 0) {
    & 'I:\eva-foundation\22-rg-sandbox\Start-Sandbox.ps1'
  } else {
    Write-Host '[SKIP] Vacation/Holiday - Auto-start cancelled'
  }
"
```

---

## 🚀 Quick Start

### Setup Vacation Calendar

1. **Edit `vacation-calendar.txt`**:
```powershell
notepad I:\eva-foundation\22-rg-sandbox\vacation-calendar.txt
```

2. **Add your vacation dates**:
```
2026-03-10 | VACATION | Personal day off
2026-08-05 | VACATION | Summer vacation
```

3. **Test the checker**:
```powershell
.\Check-VacationCalendar.ps1
```

### Use Individual Service Management

**Scenario 1: Restart Backend After Code Update**
```powershell
# Interactive
.\Manage-SandboxServices.ps1
# Select 4 (Individual), then select backend, then Restart

# Or non-interactive
.\Manage-SandboxServices.ps1 -ServiceName "marco-sandbox-backend" -Action Restart
```

**Scenario 2: Stop Just Functions for Debugging**
```powershell
.\Manage-SandboxServices.ps1 -ServiceName "marco-sandbox-func" -Action Stop
```

**Scenario 3: Quick Status Check**
```powershell
.\Manage-SandboxServices.ps1 -ListOnly
```

### Enable Vacation-Aware Scheduling

1. **Run as Administrator**:
```powershell
# Right-click PowerShell → Run as Administrator
cd I:\eva-foundation\22-rg-sandbox
.\Schedule-Sandbox.ps1
```

2. **Vacation calendar is enabled automatically** if `Check-VacationCalendar.ps1` exists

3. **Verify**:
```powershell
# Open Task Scheduler
taskschd.msc

# Check "Sandbox-AutoStart" task
# Action command should include vacation check
```

---

## 📋 Common Workflows

### Morning: Backend Won't Start
```powershell
# 1. Check status
.\Manage-SandboxServices.ps1 -ListOnly

# 2. Restart backend individually
.\Manage-SandboxServices.ps1 -ServiceName "marco-sandbox-backend" -Action Restart

# 3. Check health
# (Menu option 4 → Select backend → Health check)
```

### Friday Before Vacation
```powershell
# 1. Add vacation dates to calendar
notepad vacation-calendar.txt
# Add: 2026-08-01 | VACATION | Week off

# 2. Manual stop for weekend
.\Stop-Sandbox.ps1 -Force

# Automatic start/stop will skip your vacation days
```

### Azure Maintenance Window
```powershell
# 1. Add maintenance date
echo "2026-06-15 | MAINTENANCE | Azure maintenance" >> vacation-calendar.txt

# 2. Services will stay in current state on 2026-06-15
# (No automatic start/stop during maintenance)
```

### Troubleshooting: Service Stuck
```powershell
# Interactive menu for detailed control
.\Manage-SandboxServices.ps1

# Select service
# Try: Stop → Wait 30s → Start
```

---

## 🎓 Advanced Usage

### Automation Scripts Using Service Manager

```powershell
# deploy-update.ps1
# Stop backend → Deploy code → Start backend

.\Manage-SandboxServices.ps1 -ServiceName "marco-sandbox-backend" -Action Stop
# ... deploy code ...
Start-Sleep -Seconds 10
.\Manage-SandboxServices.ps1 -ServiceName "marco-sandbox-backend" -Action Start
```

### Bulk Service Control

```powershell
# Stop all compute (save costs for extended downtime)
.\Manage-SandboxServices.ps1
# Select 2 (Stop ALL)

# Start all compute (quick startup)
.\Manage-SandboxServices.ps1
# Select 1 (Start ALL)
```

### Calendar Management

**Bulk Add Holidays**:
```powershell
# Add entire vacation period
$vacationDates = "2026-08-01", "2026-08-02", "2026-08-03", "2026-08-04", "2026-08-05"
foreach ($date in $vacationDates) {
    Add-Content -Path ".\vacation-calendar.txt" -Value "$date | VACATION | Summer break"
}
```

**Remove Past Dates** (yearly cleanup):
```powershell
# Keep only future dates
$today = Get-Date
$lines = Get-Content ".\vacation-calendar.txt"
$filtered = $lines | Where-Object {
    if ($_ -match '^(\d{4}-\d{2}-\d{2})') {
        $date = [DateTime]::ParseExact($matches[1], "yyyy-MM-dd", $null)
        return $date -ge $today
    }
    return $true  # Keep comments and headers
}
$filtered | Set-Content ".\vacation-calendar.txt"
```

---

## 🔮 Future Enhancements (Roadmap)

### Phase 2: Database Backend
- Store calendar in Azure Cosmos DB
- Web UI for calendar management
- Team-shared vacation calendars
- Calendar sync with Outlook/Google Calendar

### Phase 3: Smart Scheduling
- Predictive analytics (usage patterns)
- Cost optimization suggestions
- Auto-scale based on workload
- Integration with Azure Advisor

### Phase 4: Service Health Monitoring
- Automated health checks
- Self-healing (auto-restart on failure)
- Performance metrics dashboard
- Alert integration (email/Teams)

---

## 📚 File Reference

| File | Purpose | Size | Last Updated |
|------|---------|------|--------------|
| `Manage-SandboxServices.ps1` | Interactive service manager | ~400 lines | 2026-02-03 |
| `vacation-calendar.txt` | Holiday/vacation calendar | ~50 lines | 2026-02-03 |
| `Check-VacationCalendar.ps1` | Calendar validation helper | ~70 lines | 2026-02-03 |
| `Schedule-Sandbox.ps1` | Auto-schedule (updated) | ~280 lines | 2026-02-03 |
| `Stop-Sandbox.ps1` | Bulk stop (existing) | ~200 lines | 2026-02-02 |
| `Start-Sandbox.ps1` | Bulk start (existing) | ~150 lines | 2026-02-02 |
| `Monitor-DailyCosts.ps1` | Cost tracking (existing) | ~150 lines | 2026-02-02 |

---

## 🎯 Cost Impact Summary

| Scenario | Monthly Cost | Savings |
|----------|--------------|---------|
| **Always-On** (no controls) | $197 | 0% |
| **Business Hours** (Mon-Fri 8AM-6PM) | $177 | $20/month (10%) |
| **+ Individual Restarts** (reduce downtime) | $175 | $22/month (11%) |
| **+ Vacation Calendar** (skip holidays) | $172 | $25/month (13%) |

**Vacation Calendar Impact**:
- 11 statutory holidays/year in Canada
- Skip auto-start/stop on these days = services stay stopped
- Additional savings: ~$3/month (1.5%)

---

**Questions?** Check [COST-CONTROL-README.md](COST-CONTROL-README.md) for basics or [COST-CONTROL-STATUS.md](COST-CONTROL-STATUS.md) for current status.
