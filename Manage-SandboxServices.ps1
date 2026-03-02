# Manage-SandboxServices.ps1
# Interactive service management with individual start/stop control

param(
    [switch]$ListOnly,
    [string]$ServiceName,
    [ValidateSet("Start", "Stop", "Restart", "Status")]
    [string]$Action
)

$ErrorActionPreference = "Continue"
$SubscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$ResourceGroup = "EsDAICoE-Sandbox"

# Service catalog with metadata
$services = @(
    @{
        Name = "marco-sandbox-backend"
        Type = "WebApp"
        Category = "Compute"
        Cost = "$13/month"
        Description = "Backend API (Quart/Python)"
        Dependencies = @("marco-sandbox-search", "marco-sandbox-cosmos")
    },
    @{
        Name = "marco-sandbox-enrichment"
        Type = "WebApp"
        Category = "Compute"
        Cost = "$13/month"
        Description = "Enrichment Service (Flask)"
        Dependencies = @("marco-sandbox-search")
    },
    @{
        Name = "marco-sandbox-func"
        Type = "FunctionApp"
        Category = "Compute"
        Cost = "$3/month"
        Description = "Document Pipeline Functions"
        Dependencies = @("marcosand20260203", "marco-sandbox-search")
    },
    @{
        Name = "marco-sandbox-search"
        Type = "SearchService"
        Category = "Infrastructure"
        Cost = "$75/month"
        Description = "Cognitive Search (cannot stop)"
        Stoppable = $false
    },
    @{
        Name = "marco-sandbox-cosmos"
        Type = "CosmosDB"
        Category = "Infrastructure"
        Cost = "$8/month"
        Description = "Cosmos DB (cannot stop)"
        Stoppable = $false
    },
    @{
        Name = "marco-sandbox-apim"
        Type = "APIM"
        Category = "Infrastructure"
        Cost = "$50/month"
        Description = "API Management Gateway (cannot stop)"
        Stoppable = $false
    },
    @{
        Name = "marcosand20260203"
        Type = "StorageAccount"
        Category = "Infrastructure"
        Cost = "$5/month"
        Description = "Storage Account (cannot stop)"
        Stoppable = $false
    }
)

function Get-ServiceStatus {
    param([hashtable]$Service)
    
    $status = @{
        Name = $Service.Name
        Type = $Service.Type
        State = "Unknown"
        URL = ""
        Stoppable = if ($null -eq $Service.Stoppable) { $true } else { $Service.Stoppable }
    }
    
    try {
        switch ($Service.Type) {
            "WebApp" {
                $app = az webapp show --name $Service.Name --resource-group $ResourceGroup --query "{state:state, url:defaultHostName}" -o json 2>$null | ConvertFrom-Json
                if ($app) {
                    $status.State = $app.state
                    $status.URL = "https://$($app.url)"
                }
            }
            "FunctionApp" {
                $func = az functionapp show --name $Service.Name --resource-group $ResourceGroup --query "{state:state, url:defaultHostName}" -o json 2>$null | ConvertFrom-Json
                if ($func) {
                    $status.State = $func.state
                    $status.URL = "https://$($func.url)"
                }
            }
            "SearchService" {
                $search = az search service show --name $Service.Name --resource-group $ResourceGroup --query "status" -o tsv 2>$null
                if ($search) { $status.State = $search }
            }
            "CosmosDB" {
                $cosmos = az cosmosdb show --name $Service.Name --resource-group $ResourceGroup --query "provisioningState" -o tsv 2>$null
                if ($cosmos) { $status.State = $cosmos }
            }
            "APIM" {
                $apim = az apim show --name $Service.Name --resource-group $ResourceGroup --query "provisioningState" -o tsv 2>$null
                if ($apim) { $status.State = $apim }
            }
            "StorageAccount" {
                $storage = az storage account show --name $Service.Name --resource-group $ResourceGroup --query "provisioningState" -o tsv 2>$null
                if ($storage) { $status.State = $storage }
            }
        }
    } catch {
        $status.State = "Error: $($_.Exception.Message)"
    }
    
    return $status
}

function Start-Service {
    param([hashtable]$Service)
    
    if ($Service.Stoppable -eq $false) {
        Write-Host "[SKIP] $($Service.Name) cannot be stopped/started" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "[INFO] Starting $($Service.Name)..." -ForegroundColor Cyan
    
    try {
        switch ($Service.Type) {
            "WebApp" {
                az webapp start --name $Service.Name --resource-group $ResourceGroup -o none
                Write-Host "[PASS] $($Service.Name) started" -ForegroundColor Green
                return $true
            }
            "FunctionApp" {
                az functionapp start --name $Service.Name --resource-group $ResourceGroup -o none
                Write-Host "[PASS] $($Service.Name) started" -ForegroundColor Green
                return $true
            }
            default {
                Write-Host "[SKIP] $($Service.Type) cannot be started via script" -ForegroundColor Yellow
                return $false
            }
        }
    } catch {
        Write-Host "[FAIL] Failed to start $($Service.Name): $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Stop-Service {
    param([hashtable]$Service)
    
    if ($Service.Stoppable -eq $false) {
        Write-Host "[SKIP] $($Service.Name) cannot be stopped" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "[INFO] Stopping $($Service.Name)..." -ForegroundColor Cyan
    
    try {
        switch ($Service.Type) {
            "WebApp" {
                az webapp stop --name $Service.Name --resource-group $ResourceGroup -o none
                Write-Host "[PASS] $($Service.Name) stopped" -ForegroundColor Green
                return $true
            }
            "FunctionApp" {
                az functionapp stop --name $Service.Name --resource-group $ResourceGroup -o none
                Write-Host "[PASS] $($Service.Name) stopped" -ForegroundColor Green
                return $true
            }
            default {
                Write-Host "[SKIP] $($Service.Type) cannot be stopped via script" -ForegroundColor Yellow
                return $false
            }
        }
    } catch {
        Write-Host "[FAIL] Failed to stop $($Service.Name): $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Restart-Service {
    param([hashtable]$Service)
    
    Write-Host "[INFO] Restarting $($Service.Name)..." -ForegroundColor Cyan
    
    $stopped = Stop-Service -Service $Service
    if ($stopped) {
        Start-Sleep -Seconds 5
        $started = Start-Service -Service $Service
        return $started
    }
    
    return $false
}

function Show-ServiceMenu {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  SANDBOX SERVICE MANAGEMENT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`n[SUBSCRIPTION]" -ForegroundColor Yellow
    Write-Host "  EsDAICoESub ($SubscriptionId)" -ForegroundColor White
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    
    Write-Host "`n[SERVICES STATUS]" -ForegroundColor Yellow
    Write-Host ""
    
    $statuses = @()
    foreach ($service in $services) {
        $status = Get-ServiceStatus -Service $service
        $statuses += $status
        
        $stateColor = switch ($status.State) {
            "Running" { "Green" }
            "Stopped" { "Gray" }
            "Succeeded" { "Green" }
            default { "Yellow" }
        }
        
        $stoppableIcon = if ($status.Stoppable) { "[CTRL]" } else { "[AUTO]" }
        
        Write-Host "  $stoppableIcon " -NoNewline -ForegroundColor $(if ($status.Stoppable) { "Cyan" } else { "Gray" })
        Write-Host "$($service.Name.PadRight(30)) " -NoNewline -ForegroundColor White
        Write-Host "$($status.State.PadRight(15)) " -NoNewline -ForegroundColor $stateColor
        Write-Host "$($service.Cost)" -ForegroundColor Gray
        Write-Host "        $($service.Description)" -ForegroundColor DarkGray
    }
    
    Write-Host "`n[LEGEND]" -ForegroundColor Yellow
    Write-Host "  [CTRL] = Can be started/stopped manually" -ForegroundColor Cyan
    Write-Host "  [AUTO] = Managed by Azure (always running)" -ForegroundColor Gray
    
    Write-Host "`n[ACTIONS]" -ForegroundColor Yellow
    Write-Host "  1. Start ALL compute services" -ForegroundColor White
    Write-Host "  2. Stop ALL compute services" -ForegroundColor White
    Write-Host "  3. Restart ALL compute services" -ForegroundColor White
    Write-Host "  4. Manage individual service" -ForegroundColor White
    Write-Host "  5. Show service dependencies" -ForegroundColor White
    Write-Host "  Q. Quit" -ForegroundColor White
    
    Write-Host ""
    $choice = Read-Host "Enter choice"
    
    switch ($choice) {
        "1" {
            Write-Host "`n[ACTION] Starting all compute services..." -ForegroundColor Cyan
            foreach ($service in $services | Where-Object { $_.Stoppable -ne $false }) {
                Start-Service -Service $service
            }
            Write-Host "`n[DONE] Press any key to continue..." -ForegroundColor Green
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-ServiceMenu
        }
        "2" {
            Write-Host "`n[ACTION] Stopping all compute services..." -ForegroundColor Cyan
            foreach ($service in $services | Where-Object { $_.Stoppable -ne $false }) {
                Stop-Service -Service $service
            }
            Write-Host "`n[DONE] Press any key to continue..." -ForegroundColor Green
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-ServiceMenu
        }
        "3" {
            Write-Host "`n[ACTION] Restarting all compute services..." -ForegroundColor Cyan
            foreach ($service in $services | Where-Object { $_.Stoppable -ne $false }) {
                Restart-Service -Service $service
            }
            Write-Host "`n[DONE] Press any key to continue..." -ForegroundColor Green
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-ServiceMenu
        }
        "4" {
            Show-IndividualServiceMenu
        }
        "5" {
            Show-ServiceDependencies
        }
        { $_ -in @("Q", "q") } {
            Write-Host "`n[EXIT] Goodbye!" -ForegroundColor Cyan
            return
        }
        default {
            Write-Host "`n[ERROR] Invalid choice" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-ServiceMenu
        }
    }
}

function Show-IndividualServiceMenu {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  INDIVIDUAL SERVICE MANAGEMENT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`n[SELECT SERVICE]" -ForegroundColor Yellow
    $controllableServices = $services | Where-Object { $_.Stoppable -ne $false }
    
    for ($i = 0; $i -lt $controllableServices.Count; $i++) {
        Write-Host "  $($i + 1). $($controllableServices[$i].Name) - $($controllableServices[$i].Description)" -ForegroundColor White
    }
    Write-Host "  B. Back to main menu" -ForegroundColor White
    
    Write-Host ""
    $choice = Read-Host "Select service number"
    
    if ($choice -eq "B" -or $choice -eq "b") {
        Show-ServiceMenu
        return
    }
    
    $serviceIndex = [int]$choice - 1
    if ($serviceIndex -ge 0 -and $serviceIndex -lt $controllableServices.Count) {
        $selectedService = $controllableServices[$serviceIndex]
        Show-ServiceActions -Service $selectedService
    } else {
        Write-Host "[ERROR] Invalid selection" -ForegroundColor Red
        Start-Sleep -Seconds 2
        Show-IndividualServiceMenu
    }
}

function Show-ServiceActions {
    param([hashtable]$Service)
    
    $status = Get-ServiceStatus -Service $Service
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  SERVICE: $($Service.Name)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`n[DETAILS]" -ForegroundColor Yellow
    Write-Host "  Type: $($Service.Type)" -ForegroundColor White
    Write-Host "  Category: $($Service.Category)" -ForegroundColor White
    Write-Host "  Cost: $($Service.Cost)" -ForegroundColor White
    Write-Host "  Description: $($Service.Description)" -ForegroundColor White
    Write-Host "  Current State: $($status.State)" -ForegroundColor $(if ($status.State -eq "Running") { "Green" } else { "Gray" })
    if ($status.URL) {
        Write-Host "  URL: $($status.URL)" -ForegroundColor Cyan
    }
    
    if ($Service.Dependencies) {
        Write-Host "  Dependencies: $($Service.Dependencies -join ', ')" -ForegroundColor DarkGray
    }
    
    Write-Host "`n[ACTIONS]" -ForegroundColor Yellow
    Write-Host "  1. Start" -ForegroundColor White
    Write-Host "  2. Stop" -ForegroundColor White
    Write-Host "  3. Restart" -ForegroundColor White
    Write-Host "  4. Check health" -ForegroundColor White
    Write-Host "  B. Back" -ForegroundColor White
    
    Write-Host ""
    $action = Read-Host "Enter action"
    
    switch ($action) {
        "1" {
            Start-Service -Service $Service
            Write-Host "`n[INFO] Press any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-ServiceActions -Service $Service
        }
        "2" {
            Stop-Service -Service $Service
            Write-Host "`n[INFO] Press any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-ServiceActions -Service $Service
        }
        "3" {
            Restart-Service -Service $Service
            Write-Host "`n[INFO] Press any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-ServiceActions -Service $Service
        }
        "4" {
            if ($status.URL) {
                Write-Host "`n[INFO] Checking health endpoint..." -ForegroundColor Cyan
                try {
                    $healthUrl = "$($status.URL)/health"
                    $response = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 5 -UseBasicParsing
                    Write-Host "[PASS] Health check successful: $($response.StatusCode)" -ForegroundColor Green
                } catch {
                    Write-Host "[FAIL] Health check failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "[INFO] No health endpoint available for this service" -ForegroundColor Yellow
            }
            Write-Host "`n[INFO] Press any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Show-ServiceActions -Service $Service
        }
        { $_ -in @("B", "b") } {
            Show-IndividualServiceMenu
        }
        default {
            Write-Host "[ERROR] Invalid action" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-ServiceActions -Service $Service
        }
    }
}

function Show-ServiceDependencies {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  SERVICE DEPENDENCY MAP" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`n[DEPENDENCY GRAPH]" -ForegroundColor Yellow
    
    foreach ($service in $services) {
        Write-Host "`n$($service.Name)" -ForegroundColor White
        if ($service.Dependencies) {
            foreach ($dep in $service.Dependencies) {
                Write-Host "  |-- depends on --> $dep" -ForegroundColor Gray
            }
        } else {
            Write-Host "  |-- no dependencies" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`n[STARTUP ORDER]" -ForegroundColor Yellow
    Write-Host "  Recommended order for starting services:" -ForegroundColor White
    Write-Host "  1. Infrastructure (Storage, Cosmos, Search)" -ForegroundColor Gray
    Write-Host "  2. Backend API" -ForegroundColor Gray
    Write-Host "  3. Enrichment Service" -ForegroundColor Gray
    Write-Host "  4. Function Apps" -ForegroundColor Gray
    
    Write-Host "`n[INFO] Press any key to return to main menu..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Show-ServiceMenu
}

# Main execution
az account set --subscription $SubscriptionId -o none

if ($ListOnly) {
    Write-Host "`n[SERVICES LIST]" -ForegroundColor Yellow
    foreach ($service in $services) {
        $status = Get-ServiceStatus -Service $service
        Write-Host "$($service.Name): $($status.State)" -ForegroundColor White
    }
    exit 0
}

if ($ServiceName -and $Action) {
    # Non-interactive mode
    $service = $services | Where-Object { $_.Name -eq $ServiceName }
    
    if (-not $service) {
        Write-Host "[ERROR] Service not found: $ServiceName" -ForegroundColor Red
        Write-Host "[INFO] Available services:" -ForegroundColor Yellow
        $services | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
        exit 1
    }
    
    switch ($Action) {
        "Start" { Start-Service -Service $service }
        "Stop" { Stop-Service -Service $service }
        "Restart" { Restart-Service -Service $service }
        "Status" {
            $status = Get-ServiceStatus -Service $service
            Write-Host "$($service.Name): $($status.State)" -ForegroundColor White
        }
    }
} else {
    # Interactive mode
    Show-ServiceMenu
}
