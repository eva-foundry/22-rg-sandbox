# Phase 4: Advanced Operations & Optimization

**Status**: Planning  
**Prerequisites**: Phase 3 complete (Cost Management exports + Data Factory pipelines operational)  
**Estimated Duration**: 2-3 weeks  
**Estimated Cost Impact**: +$10-20/month (monitoring overhead) with $20-40/month savings potential

---

## Phase 4 Overview

**Goal**: Transform sandbox from basic deployment to enterprise-grade operational environment

**Success Criteria**:
- ✅ Proactive monitoring with automated alerts
- ✅ Auto-scaling policies reduce costs during idle periods
- ✅ Automated cost optimization runs weekly
- ✅ Backup & disaster recovery tested and verified
- ✅ 30% cost reduction through optimization

---

## 4.1 Monitoring & Alerting Requirements

### Application Performance Monitoring

**Azure Application Insights** (existing, enhance configuration):

**Metrics to Track**:
- Request duration (P50, P95, P99)
- Dependency call latency (Search, Cosmos, OpenAI)
- Exception rate (errors per minute)
- Availability (uptime percentage)
- User session count

**Alert Thresholds**:
```yaml
Critical Alerts:
  - Availability < 99% for 5 minutes
  - Exception rate > 10/minute for 5 minutes
  - Average response time > 5 seconds for 10 minutes
  
Warning Alerts:
  - P95 response time > 3 seconds for 15 minutes
  - Dependency failures > 5% for 10 minutes
  - Memory usage > 80% for 10 minutes
```

**Implementation**:
```powershell
# Script: Deploy-Application-Alerts.ps1
$alertRules = @(
    @{
        Name = "High Response Time"
        Metric = "requests/duration"
        Threshold = 5000  # milliseconds
        Window = "PT10M"
        Severity = 2
    },
    @{
        Name = "High Exception Rate"
        Metric = "exceptions/count"
        Threshold = 10
        Window = "PT5M"
        Severity = 1
    }
)

foreach ($rule in $alertRules) {
    az monitor metrics alert create `
        --name $rule.Name `
        --resource-group EsDAICoE-Sandbox `
        --scopes "/subscriptions/.../microsoft.insights/components/marco-sandbox-appinsights" `
        --condition "avg $($rule.Metric) > $($rule.Threshold)" `
        --window-size $rule.Window `
        --severity $rule.Severity `
        --action email marco.presta@hrsdc-rhdcc.gc.ca
}
```

---

### Infrastructure Monitoring

**Azure Monitor Metrics**:

**Search Service**:
- Query latency (ms)
- Throttled requests (count)
- Index size (GB)
- Document count

**Cosmos DB**:
- Request units consumed (RU/s)
- Throttled requests (429 errors)
- Storage used (GB)
- Replication lag (if multi-region)

**Web Apps**:
- CPU percentage
- Memory percentage
- HTTP queue length
- Instance count

**Storage Accounts**:
- Ingress/Egress (GB)
- Transaction count
- Availability percentage
- Used capacity (GB)

**Alert Configuration**:
```yaml
Search Alerts:
  - Throttled requests > 0 for 5 minutes (Warning)
  - Query latency P95 > 500ms for 10 minutes (Warning)

Cosmos DB Alerts:
  - RU/s consumed > 80% provisioned for 15 minutes (Warning)
  - 429 throttling > 10/minute for 5 minutes (Critical)

Web App Alerts:
  - CPU > 80% for 15 minutes (Warning)
  - Memory > 90% for 10 minutes (Critical)
  - Instance count = 1 for 5 minutes (Info - no redundancy)

Storage Alerts:
  - Used capacity > 80% quota for 1 day (Warning)
  - Availability < 99.9% for 1 hour (Critical)
```

**Implementation Script**: `Deploy-Infrastructure-Alerts.ps1`

---

### Cost Monitoring Alerts

**Budget Alerts** (already configured via cost-alerts-config.json):

**Enhancement**: Add forecast alerts
```json
{
  "name": "Sandbox Forecast Alert",
  "type": "ForecastBudget",
  "amount": 200,
  "timeGrain": "Monthly",
  "timePeriod": {
    "startDate": "2026-02-01"
  },
  "notifications": {
    "forecast-80": {
      "enabled": true,
      "operator": "GreaterThan",
      "threshold": 80,
      "contactEmails": ["marco.presta@hrsdc-rhdcc.gc.ca"],
      "thresholdType": "Forecasted"
    }
  }
}
```

**Daily Cost Spike Detection**:
```powershell
# Monitor-DailyCosts.ps1 (enhance existing)
$threshold = 10  # $10/day baseline
$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")

# Query Cost Management for yesterday's costs
$costs = az costmanagement query `
    --type Usage `
    --dataset-filter "ResourceGroupName eq 'EsDAICoE-Sandbox' and UsageDate eq '$yesterday'" `
    --timeframe Custom `
    --time-period from=$yesterday to=$yesterday `
    --query "properties.rows[].sum()" `
    --output tsv

if ($costs -gt $threshold) {
    Send-MailMessage -To "marco.presta@hrsdc-rhdcc.gc.ca" `
        -Subject "[ALERT] Sandbox daily cost spike: $$costs" `
        -Body "Yesterday's cost ($$costs) exceeded baseline ($$threshold). Review resources."
}
```

**Run via Azure Automation**: Daily at 8 AM EST

---

### Log Analytics Queries

**Saved Queries** (create in Log Analytics workspace):

**1. Top 10 Slowest Requests**:
```kql
requests
| where timestamp > ago(1h)
| summarize avg(duration), count() by operation_Name
| top 10 by avg_duration desc
```

**2. Exception Trends**:
```kql
exceptions
| where timestamp > ago(24h)
| summarize count() by bin(timestamp, 1h), type
| render timechart
```

**3. Dependency Failure Rate**:
```kql
dependencies
| where timestamp > ago(1h)
| summarize total=count(), failures=countif(success == false) by target
| extend failureRate = (failures * 100.0) / total
| where failureRate > 0
| project target, failureRate, failures, total
```

**4. Cost by Resource Type** (from Data Factory aggregations):
```kql
CostAggregatedByType_CL
| where TimeGenerated > ago(7d)
| summarize TotalCost=sum(Cost_d) by ResourceType_s
| order by TotalCost desc
| render piechart
```

---

## 4.2 Auto-Scaling Policies

### Current State
- **Backend ASP**: B1 (1 core, 1.75 GB, always-on)
- **Enrichment ASP**: B1 (1 core, 1.75 GB, always-on)
- **Function App**: Consumption (auto-scales by default)

**Problem**: Web apps run 24/7 even during idle periods (nights, weekends)

**Cost Opportunity**: 
- Current: $13/month x 2 = $26/month (24/7 operation)
- Optimized: ~$15-18/month (scale down during off-hours)
- **Savings**: $8-11/month (30-42% reduction on Web Apps)

---

### Auto-Scaling Strategy

**Option A: Scale Down/Up Based on Schedule** (Simplest)

**Business Hours**: 8 AM - 6 PM EST, Monday-Friday
**Off-Hours**: Evenings + Weekends

**Schedule**:
```yaml
Scale Down (to 0 instances):
  - Monday-Friday: 6 PM to 8 AM
  - Saturday-Sunday: All day
  
Scale Up (to 1 instance):
  - Monday-Friday: 8 AM to 6 PM
```

**Implementation**:
```powershell
# Schedule-Auto-Scaling.ps1
$resourceGroup = "EsDAICoE-Sandbox"
$appServicePlans = @("marco-sandbox-asp-backend", "marco-sandbox-asp-enrichment")

# Scale down rule (evenings)
foreach ($plan in $appServicePlans) {
    az monitor autoscale create `
        --resource-group $resourceGroup `
        --resource $plan `
        --resource-type Microsoft.Web/serverfarms `
        --name "${plan}-autoscale" `
        --min-count 0 `
        --max-count 1 `
        --count 1
    
    # Scale down: 6 PM EST
    az monitor autoscale rule create `
        --resource-group $resourceGroup `
        --autoscale-name "${plan}-autoscale" `
        --scale to 0 `
        --schedule "0 18 * * 1-5"  # 6 PM weekdays
    
    # Scale up: 8 AM EST
    az monitor autoscale rule create `
        --resource-group $resourceGroup `
        --autoscale-name "${plan}-autoscale" `
        --scale to 1 `
        --schedule "0 8 * * 1-5"  # 8 AM weekdays
}
```

**Caveat**: B1 tier doesn't support auto-scaling. Need to:
1. Upgrade to S1 ($73/month) for auto-scale support, OR
2. Use Azure Automation to stop/start apps on schedule

**Recommended**: Azure Automation approach (cheaper)

---

**Option B: Azure Automation Stop/Start** (Cost-Effective)

**Implementation**:
```powershell
# Runbook: Stop-SandboxApps.ps1
param(
    [string]$ResourceGroup = "EsDAICoE-Sandbox"
)

$webApps = @("marco-sandbox-backend", "marco-sandbox-enrichment")

foreach ($app in $webApps) {
    Write-Output "Stopping $app"
    az webapp stop --resource-group $ResourceGroup --name $app
}

# Runbook: Start-SandboxApps.ps1
foreach ($app in $webApps) {
    Write-Output "Starting $app"
    az webapp start --resource-group $ResourceGroup --name $app
}
```

**Schedule**:
- Stop: 6 PM EST (weekdays), 12 AM (weekends)
- Start: 8 AM EST (weekdays)

**Cost**: Azure Automation free tier (500 minutes/month included)

**Expected Savings**:
- Off-hours: ~14 hours/day weekdays + 48 hours weekends = 118 hours/week
- Running: 50 hours/week (10 hours/day x 5 days)
- Reduction: 70% idle time
- **Savings**: $26/month x 70% = ~$18/month savings
- **Net Cost After Automation**: $8/month for Web Apps

---

**Option C: Metric-Based Auto-Scaling** (Most Dynamic)

**Trigger**: CPU usage or HTTP queue length

```yaml
Scale Out (add instance):
  - CPU > 70% for 10 minutes
  - HTTP queue > 100 for 5 minutes
  
Scale In (remove instance):
  - CPU < 30% for 20 minutes
  - HTTP queue < 10 for 20 minutes
```

**Limitation**: Requires Standard tier ($73/month), not cost-effective for sandbox

---

### Recommendation

**Phase 4.2 Implementation**:
1. Deploy Azure Automation stop/start runbooks
2. Schedule: Stop 6 PM, Start 8 AM (weekdays only)
3. Weekend: Keep stopped unless testing needed
4. Override: Manual start for after-hours work

**Expected Outcome**: $18/month savings on Web Apps

---

## 4.3 Cost Optimization Automation

### Weekly Cost Review Automation

**Goal**: Automated weekly analysis of costs with optimization recommendations

**Script**: `Analyze-Weekly-Costs.ps1`

**Data Source**: Data Factory aggregations (from Phase 3)

**Analysis**:
1. **Top 10 Most Expensive Resources**
2. **Cost Trend** (week-over-week change)
3. **Idle Resources** (zero activity detected)
4. **Optimization Opportunities**

**Implementation**:
```powershell
# Analyze-Weekly-Costs.ps1
$lastWeek = (Get-Date).AddDays(-7)
$thisWeek = Get-Date

# Query aggregated costs from Data Factory output
$costs = Get-Content "\\marcosandboxfinopshub\costs\aggregated\by-resource-type.json" | ConvertFrom-Json

# Analyze trends
$report = @{
    TopResources = $costs | Sort-Object Cost -Descending | Select-Object -First 10
    TotalCost = ($costs | Measure-Object -Property Cost -Sum).Sum
    IdleResources = @()
    Recommendations = @()
}

# Detect idle resources (zero usage)
$idleThreshold = 0.01
foreach ($resource in $costs) {
    if ($resource.Cost -lt $idleThreshold -and $resource.Type -notin @("KeyVault", "Storage")) {
        $report.IdleResources += $resource
        $report.Recommendations += "Consider deleting idle resource: $($resource.Name)"
    }
}

# Check for over-provisioned services
$searchCost = ($costs | Where-Object Type -eq "Microsoft.Search/searchServices").Cost
if ($searchCost -gt 80) {
    $report.Recommendations += "Search service cost high ($searchCost/month). Consider Basic tier if not using advanced features."
}

# Generate email report
$body = @"
Weekly Cost Report - EsDAICoE-Sandbox
Total Cost: $$($report.TotalCost)

Top 10 Resources:
$($report.TopResources | Format-Table -AutoSize | Out-String)

Optimization Recommendations:
$($report.Recommendations -join "`n")
"@

Send-MailMessage -To "marco.presta@hrsdc-rhdcc.gc.ca" `
    -Subject "Sandbox Weekly Cost Report" `
    -Body $body
```

**Schedule**: Every Monday 9 AM EST (Azure Automation)

---

### Right-Sizing Recommendations

**Automated Analysis**:

**Search Service** (currently Basic $75/month):
- Monitor: Query volume, index size, document count
- If avg queries < 10/hour AND index < 1 GB: Stays Basic ✅
- If avg queries > 100/hour OR index > 10 GB: Recommend Standard ($250/month)

**Cosmos DB** (currently Serverless ~$10/month):
- Monitor: Request units consumed per month
- If RU/month < 1M consistently: Keep Serverless ✅
- If RU/month > 5M consistently: Recommend Provisioned throughput

**App Service Plans** (currently B1 $13/month each):
- Monitor: CPU %, Memory %, Response time
- If CPU < 20% AND Memory < 50% consistently: Keep B1 ✅
- If CPU > 70% frequently: Recommend B2 ($26/month)

**Implementation**: `Recommend-Right-Sizing.ps1` (monthly analysis)

---

### Unused Resource Detection

**Automated Cleanup Candidates**:

```powershell
# Detect-Unused-Resources.ps1

# 1. Storage blobs not accessed in 90 days
$oldBlobs = az storage blob list `
    --account-name marcosand20260203 `
    --container-name documents `
    --query "[?properties.lastModified < '$(Get-Date -Format yyyy-MM-dd)']" `
    --output json | ConvertFrom-Json

if ($oldBlobs.Count -gt 0) {
    Write-Output "Found $($oldBlobs.Count) blobs not accessed in 90 days"
    # Archive to cool tier or delete
}

# 2. Cosmos DB items with expired TTL
# (Cosmos DB auto-deletes with TTL configured)

# 3. Orphaned resources (no dependencies)
$allResources = az resource list --resource-group EsDAICoE-Sandbox --output json | ConvertFrom-Json
$orphanCheck = @(
    "No App Service Plan references this Web App",
    "No search index in this Search service",
    "No containers in this Storage Account"
)

# Generate report
```

**Schedule**: Monthly (first Monday of month)

---

## 4.4 Backup & Disaster Recovery

### Backup Strategy

**Recovery Objectives**:
- **RTO (Recovery Time Objective)**: 4 hours
- **RPO (Recovery Point Objective)**: 24 hours (daily backups)

---

### What to Backup

**1. Azure Cognitive Search Index**

**Method**: Export index definition + documents

```powershell
# Backup-Search-Index.ps1
$searchService = "marco-sandbox-search"
$indexName = "index-jurisprudence"
$backupPath = "\\marcosandboxfinopshub\backups\search"

# Export index definition
az search index show `
    --service-name $searchService `
    --name $indexName `
    --output json > "$backupPath\$indexName-schema-$(Get-Date -Format yyyyMMdd).json"

# Export documents (use Search SDK)
# Note: Basic tier has no built-in backup, must export manually
```

**Frequency**: Weekly (Sunday 2 AM)  
**Retention**: 4 weeks

**Recovery**: Re-create index from schema, re-index documents from blob storage

---

**2. Cosmos DB Collections**

**Method**: Point-in-time restore (built-in for Serverless)

```powershell
# Cosmos DB continuous backup is automatic for Serverless tier
# Restore command (when needed):
az cosmosdb sql database restore `
    --account-name marco-sandbox-cosmos `
    --restore-timestamp "2026-02-03T00:00:00Z" `
    --database-name conversations
```

**Backup**: Automatic continuous backup (7 days retention)  
**Cost**: Included in Serverless pricing

**Alternative**: Manual export for long-term retention

```powershell
# Backup-Cosmos-Collections.ps1
$cosmosAccount = "marco-sandbox-cosmos"
$database = "conversations"
$collections = @("sessions", "logs")
$backupPath = "\\marcosandboxfinopshub\backups\cosmos"

foreach ($collection in $collections) {
    # Use Data Factory or Cosmos DB Change Feed to export
    # Export to JSON in blob storage
}
```

**Frequency**: Daily (2 AM)  
**Retention**: 30 days

---

**3. Blob Storage Documents**

**Method**: Azure Blob versioning + soft delete

```powershell
# Enable versioning and soft delete
az storage account blob-service-properties update `
    --account-name marcosand20260203 `
    --enable-versioning true `
    --enable-delete-retention true `
    --delete-retention-days 30
```

**Backup**: Automatic versioning  
**Cost**: Minimal (versions are incremental)

**Alternative**: Geo-redundant storage (GRS)
- Current: Standard_LRS ($5/month)
- Upgrade to: Standard_GRS ($10/month, +$5/month)
- **Benefit**: Automatic replication to secondary region

---

**4. Configuration & Infrastructure**

**Method**: Infrastructure as Code (Terraform) + Git

```powershell
# Current: All infrastructure defined in code (not yet committed to Git)
# TODO: Commit Terraform state to version control

# Backup Terraform state
$terraformState = ".terraform\terraform.tfstate"
$backupPath = "\\marcosandboxfinopshub\backups\terraform"

Copy-Item $terraformState "$backupPath\terraform.tfstate.$(Get-Date -Format yyyyMMdd).backup"
```

**Frequency**: After every infrastructure change  
**Retention**: Indefinite (version control)

---

**5. Application Code**

**Method**: Git repository (already backed up)

- EVA-JP-v1.2 code in Git (I:\EVA-JP-v1.2)
- Function App code in Git (I:\EVA-JP-v1.2\functions)

**No additional backup needed** (Git is the backup)

---

### Disaster Recovery Procedure

**Scenario 1: Single Resource Failure**

**Example**: Search service deleted accidentally

**Recovery Steps**:
1. Restore from Terraform: `terraform apply` (re-creates resource)
2. Restore index definition from backup
3. Re-index documents from blob storage (use Function App)
4. Verify search queries work

**Estimated Time**: 2 hours

---

**Scenario 2: Data Loss (Cosmos DB)**

**Example**: Cosmos DB collection deleted

**Recovery Steps**:
1. Point-in-time restore: `az cosmosdb sql database restore`
2. Verify data integrity
3. Update connection strings if needed

**Estimated Time**: 30 minutes

---

**Scenario 3: Complete Resource Group Deletion**

**Example**: Entire EsDAICoE-Sandbox resource group deleted

**Recovery Steps**:
1. Re-create resource group
2. Run Terraform: `terraform apply` (all infrastructure)
3. Restore Search index from backup
4. Restore Cosmos DB from point-in-time
5. Re-deploy application code (Web Apps + Functions)
6. Restore configuration (environment variables, secrets)
7. Verify end-to-end functionality

**Estimated Time**: 4 hours

**Prerequisites**:
- Terraform state backup available
- Search index backup available
- Cosmos DB within 7-day restore window
- Application code in Git

---

### Backup Automation Schedule

| Backup Type | Frequency | Retention | Storage Location |
|-------------|-----------|-----------|------------------|
| Search index schema | Weekly (Sun 2 AM) | 4 weeks | marcosandboxfinopshub/backups/search |
| Search documents | Manual (on-demand) | N/A | Re-index from blobs |
| Cosmos DB collections | Daily (2 AM) | 30 days | marcosandboxfinopshub/backups/cosmos |
| Blob storage | Automatic versioning | 30 days | Built-in versioning |
| Terraform state | After each change | Indefinite | marcosandboxfinopshub/backups/terraform |
| Application code | Continuous (Git) | Indefinite | Git repository |

**Total Backup Storage Cost**: ~$2/month (5 GB estimated)

---

### Disaster Recovery Testing

**Quarterly DR Drill** (every 3 months):

1. **Test 1**: Restore Cosmos DB collection from 24 hours ago
2. **Test 2**: Re-create Search index from backup
3. **Test 3**: Full resource group recovery simulation (in separate test RG)

**Documentation**: Record recovery times, update procedures

---

## Phase 4 Implementation Timeline

### Week 1: Monitoring & Alerting
- **Day 1-2**: Deploy Application Insights alerts
- **Day 3-4**: Deploy infrastructure monitoring alerts
- **Day 5**: Deploy cost monitoring enhancements

**Deliverables**:
- 15+ alert rules configured
- Email notifications tested
- Log Analytics saved queries created

---

### Week 2: Auto-Scaling & Cost Optimization
- **Day 1-2**: Deploy Azure Automation stop/start runbooks
- **Day 3**: Test auto-scaling schedule
- **Day 4-5**: Deploy weekly cost analysis automation

**Deliverables**:
- Auto-start/stop working (6 PM / 8 AM schedule)
- Weekly cost report automation tested
- Right-sizing analysis script deployed

---

### Week 3: Backup & Disaster Recovery
- **Day 1-2**: Configure backup scripts (Search, Cosmos, Terraform)
- **Day 3**: Schedule backup automation (Azure Automation)
- **Day 4**: Test restore procedures (all backup types)
- **Day 5**: Document DR playbook, conduct initial DR drill

**Deliverables**:
- Backup automation operational
- DR procedures tested and documented
- Recovery time objectives validated

---

## Success Metrics

### Monitoring & Alerting
- ✅ Zero critical incidents missed (100% alert coverage)
- ✅ Mean time to detect (MTTD) < 5 minutes
- ✅ False positive rate < 10%

### Auto-Scaling & Cost Optimization
- ✅ 30% reduction in Web App costs ($26 → $18/month)
- ✅ Weekly cost reports delivered on time
- ✅ Zero idle resources > 30 days

### Backup & Disaster Recovery
- ✅ All backups complete successfully (100% success rate)
- ✅ Recovery Time Objective (RTO) < 4 hours (tested)
- ✅ Recovery Point Objective (RPO) < 24 hours (tested)

---

## Cost Impact Summary

| Component | Current | Phase 4 | Change |
|-----------|---------|---------|--------|
| **Web Apps** | $26/month | $18/month | -$8 (auto-scaling) |
| **Monitoring** | $0 (existing) | $5/month | +$5 (enhanced alerts) |
| **Backup Storage** | $0 | $2/month | +$2 (backup retention) |
| **Azure Automation** | $0 | $0 (free tier) | $0 |
| **Net Impact** | $182/month | $181/month | **-$1/month** |

**Long-term Savings Potential**: $20-40/month through optimization automation

---

## Next Steps

1. **Get Approval**: Review Phase 4 plan with stakeholders
2. **Schedule Work**: 3-week implementation window
3. **Allocate Resources**: Marco (2-3 hours/day for 3 weeks)
4. **Dependency**: Phase 3 must be complete (Cost Management exports operational)

---

**Last Updated**: February 4, 2026  
**Owner**: Marco Presta  
**Status**: Ready for approval after Phase 3 completion
