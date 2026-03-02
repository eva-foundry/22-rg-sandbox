#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure custom cost tracking for sandbox RAG system

.DESCRIPTION
    Sets up:
    - Custom metrics for token usage tracking
    - Cost alerts and thresholds
    - Power BI dashboard queries
    - Backend code integration

.EXAMPLE
    .\Configure-CostTracking.ps1
    Configure all cost tracking components
#>

[CmdletBinding()]
param(
    [string]$ResourceGroup = "EsDAICoE-Sandbox",
    [string]$AppInsightsName = "marco-sandbox-appinsights",
    [string]$LogWorkspaceName = "marco-sandbox-logs",
    [string]$AlertEmail = "marco.presta@hrsdc-rhdcc.gc.ca",
    [decimal]$DailyCostThreshold = 20.00
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configure Sandbox Cost Tracking" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"

Write-Host "[1/4] Configuring custom metrics in Application Insights..." -ForegroundColor Cyan

# Get App Insights ID
$appInsightsId = az monitor app-insights component show `
    --app $AppInsightsName `
    --resource-group $ResourceGroup `
    --query 'id' -o tsv

if (-not $appInsightsId) {
    Write-Host "[ERROR] Application Insights not found: $AppInsightsName" -ForegroundColor Red
    Write-Host "[INFO] Deploy base sandbox first: .\Deploy-Sandbox-AzCLI.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "[PASS] Application Insights found" -ForegroundColor Green

# Create backend integration code snippet
$backendCodeSnippet = @'
# Add to app/backend/approaches/chatreadretrieveread.py

from opencensus.ext.azure import metrics_exporter
from opencensus.stats import aggregation as aggregation_module
from opencensus.stats import measure as measure_module
from opencensus.stats import stats as stats_module
from opencensus.stats import view as view_module
from opencensus.tags import tag_map as tag_map_module

# Initialize metrics
stats = stats_module.stats
view_manager = stats.view_manager
stats_recorder = stats.stats_recorder

# Define measures
openai_tokens_measure = measure_module.MeasureInt(
    "openai_tokens_used",
    "Number of OpenAI tokens consumed",
    "tokens"
)

openai_cost_measure = measure_module.MeasureFloat(
    "openai_cost_usd",
    "Cost of OpenAI API calls in USD",
    "usd"
)

search_ru_measure = measure_module.MeasureInt(
    "search_ru_consumed",
    "Azure Search Request Units consumed",
    "ru"
)

# Define views
openai_tokens_view = view_module.View(
    "openai_tokens_total",
    "Total OpenAI tokens used",
    ["operation", "user_id", "cost_center"],
    openai_tokens_measure,
    aggregation_module.SumAggregation()
)

openai_cost_view = view_module.View(
    "openai_cost_total",
    "Total OpenAI API cost in USD",
    ["operation", "user_id", "cost_center"],
    openai_cost_measure,
    aggregation_module.SumAggregation()
)

search_ru_view = view_module.View(
    "search_ru_total",
    "Total Azure Search RU consumed",
    ["query_type", "user_id"],
    search_ru_measure,
    aggregation_module.SumAggregation()
)

# Register views
view_manager.register_view(openai_tokens_view)
view_manager.register_view(openai_cost_view)
view_manager.register_view(search_ru_view)

# Configure exporter
exporter = metrics_exporter.new_metrics_exporter(
    connection_string=os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
)
view_manager.register_exporter(exporter)

# Usage in RAG approach
def track_openai_usage(operation: str, user_id: str, tokens: int, cost: float):
    """Track OpenAI API usage"""
    mmap = stats_recorder.new_measurement_map()
    tmap = tag_map_module.TagMap()
    
    tmap.insert("operation", operation)
    tmap.insert("user_id", user_id)
    tmap.insert("cost_center", "EsDAICoE-Sandbox")
    
    mmap.measure_int_put(openai_tokens_measure, tokens)
    mmap.measure_float_put(openai_cost_measure, cost)
    
    mmap.record(tmap)

def track_search_usage(query_type: str, user_id: str, ru_consumed: int):
    """Track Azure Search usage"""
    mmap = stats_recorder.new_measurement_map()
    tmap = tag_map_module.TagMap()
    
    tmap.insert("query_type", query_type)
    tmap.insert("user_id", user_id)
    
    mmap.measure_int_put(search_ru_measure, ru_consumed)
    
    mmap.record(tmap)

# Example integration in run() method
async def run(...):
    # ... existing code ...
    
    # After OpenAI completion
    completion_tokens = response.usage.total_tokens
    completion_cost = calculate_openai_cost(
        model="gpt-4",
        tokens=completion_tokens
    )
    
    track_openai_usage(
        operation="chat_completion",
        user_id=user_id,
        tokens=completion_tokens,
        cost=completion_cost
    )
    
    # After search query
    search_ru = response.headers.get("x-ms-documentdb-request-charge", 0)
    track_search_usage(
        query_type="hybrid_vector",
        user_id=user_id,
        ru_consumed=int(search_ru)
    )

def calculate_openai_cost(model: str, tokens: int) -> float:
    """Calculate OpenAI API cost based on model and token usage"""
    pricing = {
        "gpt-4": {"input": 0.03/1000, "output": 0.06/1000},
        "gpt-4-32k": {"input": 0.06/1000, "output": 0.12/1000},
        "gpt-3.5-turbo": {"input": 0.0015/1000, "output": 0.002/1000},
        "text-embedding-ada-002": {"input": 0.0001/1000, "output": 0}
    }
    
    # Simplified: assume 50/50 input/output split
    if model in pricing:
        avg_cost = (pricing[model]["input"] + pricing[model]["output"]) / 2
        return tokens * avg_cost
    
    return 0.0
'@

$backendCodeFile = Join-Path $PSScriptRoot "backend-cost-tracking-integration.py"
$backendCodeSnippet | Out-File -FilePath $backendCodeFile -Encoding utf8

Write-Host "[PASS] Backend integration code created: $backendCodeFile" -ForegroundColor Green
Write-Host "[INFO] Add this code to your RAG approach classes" -ForegroundColor Gray

Write-Host ""
Write-Host "[2/4] Creating cost alert rules..." -ForegroundColor Cyan

# Get Log Analytics workspace ID
$workspaceId = az monitor log-analytics workspace show `
    --resource-group $ResourceGroup `
    --workspace-name $LogWorkspaceName `
    --query 'id' -o tsv 2>$null

if (-not $workspaceId) {
    Write-Host "[WARN] Log Analytics workspace not found. Creating..." -ForegroundColor Yellow
    az monitor log-analytics workspace create `
        --resource-group $ResourceGroup `
        --workspace-name $LogWorkspaceName `
        --location "canadacentral" `
        --sku PerGB2018
    
    $workspaceId = az monitor log-analytics workspace show `
        --resource-group $ResourceGroup `
        --workspace-name $LogWorkspaceName `
        --query 'id' -o tsv
}

# Create action group for email alerts
$actionGroupName = "marco-sandbox-cost-alerts"

az monitor action-group create `
    --name $actionGroupName `
    --resource-group $ResourceGroup `
    --short-name "CostAlert" `
    --email-receiver name="Marco" email-address=$AlertEmail

Write-Host "[PASS] Action group created: $actionGroupName" -ForegroundColor Green

# Create alert rule for daily cost threshold
$alertRuleName = "marco-sandbox-daily-cost-threshold"
$alertQuery = @"
customMetrics
| where name == "openai_cost_total"
| where timestamp > ago(1d)
| summarize TotalCost = sum(value) by bin(timestamp, 1d)
| where TotalCost > $DailyCostThreshold
"@

$alertQueryFile = Join-Path $PSScriptRoot "alert-query-temp.kql"
$alertQuery | Out-File -FilePath $alertQueryFile -Encoding utf8

az monitor scheduled-query create `
    --name $alertRuleName `
    --resource-group $ResourceGroup `
    --location "canadacentral" `
    --scopes $workspaceId `
    --condition "count > 0" `
    --condition-query $alertQuery `
    --evaluation-frequency 30m `
    --window-size 1h `
    --severity 2 `
    --action-groups $actionGroupName `
    --description "Alert when daily OpenAI costs exceed `$$DailyCostThreshold"

Remove-Item -Path $alertQueryFile -Force -ErrorAction SilentlyContinue

Write-Host "[PASS] Alert rule created: $alertRuleName" -ForegroundColor Green
Write-Host "[INFO] Threshold: `$$DailyCostThreshold per day" -ForegroundColor Gray

Write-Host ""
Write-Host "[3/4] Creating Power BI dashboard queries..." -ForegroundColor Cyan

# Create KQL queries for Power BI
$powerBIQueries = @'
-- Query 1: Daily Cost Tracking
customMetrics
| where name in ("openai_cost_total", "search_ru_total")
| extend CostCenter = tostring(customDimensions.cost_center)
| extend UserId = tostring(customDimensions.user_id)
| extend Operation = tostring(customDimensions.operation)
| summarize TotalCost = sum(value) by bin(timestamp, 1d), Operation, CostCenter
| order by timestamp desc

-- Query 2: Per-User Cost Attribution
customMetrics
| where name == "openai_cost_total"
| extend UserId = tostring(customDimensions.user_id)
| extend CostCenter = tostring(customDimensions.cost_center)
| summarize TotalCost = sum(value), CallCount = count() by UserId, CostCenter
| order by TotalCost desc

-- Query 3: API Usage Patterns
requests
| where url startswith "https://marco-sandbox-apim.azure-api.net"
| extend Operation = tostring(customDimensions.operation)
| extend UserId = tostring(customDimensions.user_id)
| summarize CallCount = count(), AvgDuration = avg(duration), ErrorCount = countif(resultCode >= 400) by bin(timestamp, 1h), Operation
| order by timestamp desc

-- Query 4: OpenAI Token Usage
customMetrics
| where name == "openai_tokens_total"
| extend Operation = tostring(customDimensions.operation)
| extend UserId = tostring(customDimensions.user_id)
| summarize TotalTokens = sum(value), CallCount = count() by Operation, UserId
| extend AvgTokensPerCall = TotalTokens / CallCount
| order by TotalTokens desc

-- Query 5: Cost by Service
customMetrics
| where name in ("openai_cost_total", "search_ru_total")
| extend Service = case(
    name == "openai_cost_total", "Azure OpenAI",
    name == "search_ru_total", "Azure Search",
    "Other"
)
| summarize TotalCost = sum(value) by bin(timestamp, 1d), Service
| render timechart

-- Query 6: Anomaly Detection (Spike in Cost)
customMetrics
| where name == "openai_cost_total"
| summarize HourlyCost = sum(value) by bin(timestamp, 1h)
| extend Baseline = avg(HourlyCost) over (order by timestamp rows between 24 preceding and 1 preceding)
| extend Anomaly = iff(HourlyCost > Baseline * 2, "Spike", "Normal")
| where Anomaly == "Spike"
| project timestamp, HourlyCost, Baseline, Anomaly
'@

$powerBIQueriesFile = Join-Path $PSScriptRoot "powerbi-kql-queries.txt"
$powerBIQueries | Out-File -FilePath $powerBIQueriesFile -Encoding utf8

Write-Host "[PASS] Power BI queries created: $powerBIQueriesFile" -ForegroundColor Green
Write-Host "[INFO] Import these queries into Power BI" -ForegroundColor Gray

Write-Host ""
Write-Host "[4/4] Creating operational runbook..." -ForegroundColor Cyan

$runbook = @'
# Sandbox Cost Tracking Operational Runbook

## Daily Operations

### Morning Health Check (5 minutes)
1. Open Power BI dashboard: Cost Tracking Overview
2. Verify yesterday's cost data loaded
3. Check for anomalies (cost spikes > 2x baseline)
4. Review top 5 users by cost

### Alert Response
**Alert: Daily Cost Threshold Exceeded**
1. Open Log Analytics workspace
2. Run query: "Top Operations by Cost (Last 24 Hours)"
3. Identify root cause:
   - Spike in user activity?
   - New expensive model deployed?
   - Inefficient queries?
4. Take action:
   - Rate limit user if abuse detected
   - Optimize query patterns
   - Adjust threshold if justified

## Weekly Operations

### Cost Review (15 minutes)
1. Generate weekly cost report from Power BI
2. Compare to previous week
3. Identify trends:
   - Growing user base?
   - Model usage shift (GPT-3.5 → GPT-4)?
   - Search query complexity increasing?
4. Update stakeholders via email

### Optimization Check (30 minutes)
1. Review "Inefficient Queries" dashboard
2. Identify optimization opportunities:
   - Queries with high token usage but low user rating
   - Repeated similar queries (add caching?)
   - Search queries returning 0 results (waste of RU)
3. Create Jira tickets for backend optimization

## Monthly Operations

### Executive Report (1 hour)
1. Generate monthly FinOps Hub report
2. Calculate key metrics:
   - Total cost (actual vs. budget)
   - Cost per user
   - Cost per conversation
   - Top 10 cost drivers
3. Create PowerPoint summary for leadership

### Budget Forecast (30 minutes)
1. Analyze 3-month cost trend
2. Project next quarter costs
3. Identify risk areas (approaching budget limit?)
4. Submit budget adjustment request if needed

## Troubleshooting

### Issue: Missing Cost Data
**Symptoms**: Power BI shows no data for recent days
**Resolution**:
1. Check Cost Management export status:
   `az costmanagement export show --name marco-sandbox-costs-daily --scope /subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox`
2. Verify last export run:
   `az costmanagement export list --scope /subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox --query "[].{name:name, lastRun:properties.schedule.recurrencePeriod.from}"`
3. Trigger manual export if needed:
   `.\Deploy-FinOpsHub-Sandbox.ps1 -TriggerExportOnly`

### Issue: Alert Not Firing
**Symptoms**: No email alert despite high costs
**Resolution**:
1. Check action group configuration:
   `az monitor action-group show --name marco-sandbox-cost-alerts --resource-group EsDAICoE-Sandbox`
2. Verify email address is correct
3. Check spam folder for alert emails
4. Test action group:
   `az monitor action-group test-notifications create --action-group marco-sandbox-cost-alerts --alert-type budget`

### Issue: APIM Logs Not Appearing in App Insights
**Symptoms**: No APIM request logs in Application Insights
**Resolution**:
1. Verify APIM logger configuration:
   `az apim logger show --resource-group EsDAICoE-Sandbox --service-name marco-sandbox-apim --logger-id appinsights-logger`
2. Check Application Insights connection:
   `az apim api diagnostics show --resource-group EsDAICoE-Sandbox --service-name marco-sandbox-apim --api-id marco-sandbox-rag-api --diagnostic-id applicationinsights`
3. Test APIM → App Insights flow:
   - Make test API call
   - Check traces in Application Insights within 5 minutes

## Key Contacts

- **Sandbox Owner**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)
- **Azure Support**: az-support@hrsdc-rhdcc.gc.ca
- **FinOps Team**: finops@hrsdc-rhdcc.gc.ca

## Useful Links

- **Azure Portal**: https://portal.azure.com/#@bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8/resource/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox
- **APIM Gateway**: https://marco-sandbox-apim.azure-api.net
- **Application Insights**: https://portal.azure.com/#@bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8/resource/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/microsoft.insights/components/marco-sandbox-appinsights
- **FinOps Hub Storage**: https://portal.azure.com/#@bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8/resource/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Storage/storageAccounts/marcosandboxfinopshub
'@

$runbookFile = Join-Path $PSScriptRoot "OPERATIONAL-RUNBOOK.md"
$runbook | Out-File -FilePath $runbookFile -Encoding utf8

Write-Host "[PASS] Operational runbook created: $runbookFile" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COST TRACKING CONFIGURATION COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[FILES CREATED]" -ForegroundColor Cyan
Write-Host "1. $backendCodeFile" -ForegroundColor White
Write-Host "   - Python code for custom metrics" -ForegroundColor Gray
Write-Host "2. $powerBIQueriesFile" -ForegroundColor White
Write-Host "   - KQL queries for Power BI dashboards" -ForegroundColor Gray
Write-Host "3. $runbookFile" -ForegroundColor White
Write-Host "   - Operational procedures and troubleshooting" -ForegroundColor Gray
Write-Host ""

Write-Host "[NEXT STEPS]" -ForegroundColor Yellow
Write-Host "1. Integrate backend code into RAG approaches" -ForegroundColor White
Write-Host "2. Deploy updated backend code to App Service" -ForegroundColor White
Write-Host "3. Create Power BI workspace and import queries" -ForegroundColor White
Write-Host "4. Test alerts by exceeding threshold" -ForegroundColor White
Write-Host "5. Train team on operational runbook" -ForegroundColor White
Write-Host ""

Write-Host "[VALIDATION]" -ForegroundColor Cyan
Write-Host "Test custom metrics:" -ForegroundColor White
Write-Host "1. Make API call through APIM" -ForegroundColor Gray
Write-Host "2. Wait 5 minutes for metrics aggregation" -ForegroundColor Gray
Write-Host "3. Check Application Insights → Metrics → Custom" -ForegroundColor Gray
Write-Host "4. Verify 'openai_cost_total' and 'openai_tokens_total' appear" -ForegroundColor Gray
Write-Host ""

Write-Host "[ALERT TESTING]" -ForegroundColor Cyan
Write-Host "Test cost alert:" -ForegroundColor White
Write-Host "1. Make 100+ API calls to trigger cost threshold" -ForegroundColor Gray
Write-Host "2. Wait 30 minutes for alert evaluation" -ForegroundColor Gray
Write-Host "3. Check email for alert notification" -ForegroundColor Gray
Write-Host "4. Verify Slack/Teams integration if configured" -ForegroundColor Gray
