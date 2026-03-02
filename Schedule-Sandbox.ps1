#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Schedule automatic start/stop of sandbox resources to minimize costs
    
.DESCRIPTION
    Sets up Windows Task Scheduler jobs to automatically start/stop sandbox
    during business hours. Saves ~$40/month by stopping outside work hours.
    
    Default Schedule:
    - START: Mon-Fri 8:00 AM ET
    - STOP: Mon-Fri 6:00 PM ET
    - Weekend: Stopped (Sat-Sun)
    
    Estimated Savings:
    - Work hours: 50 hours/week running
    - Off hours: 118 hours/week stopped
    - Savings: ~70% of compute costs = $27/month
    
.PARAMETER Remove
    Remove scheduled tasks
    
.PARAMETER StartTime
    Time to start sandbox daily (default: 08:00)
    
.PARAMETER StopTime
    Time to stop sandbox daily (default: 18:00)
    
.PARAMETER WorkDaysOnly
    Only run Mon-Fri (default: $true)
    
.PARAMETER WhatIf
    Preview schedule without creating tasks
    
.EXAMPLE
    .\Schedule-Sandbox.ps1
    Set up default schedule (8AM-6PM Mon-Fri)
    
.EXAMPLE
    .\Schedule-Sandbox.ps1 -StartTime "07:00" -StopTime "19:00"
    Custom hours (7AM-7PM)
    
.EXAMPLE
    .\Schedule-Sandbox.ps1 -WorkDaysOnly:$false
    Run 7 days/week
    
.EXAMPLE
    .\Schedule-Sandbox.ps1 -Remove
    Remove scheduled tasks
    
.NOTES
    Requires Administrator privileges to create scheduled tasks
#>

param(
    [switch]$Remove,
    [string]$StartTime = "08:00",
    [string]$StopTime = "18:00",
    [bool]$WorkDaysOnly = $true,
    [switch]$WhatIf,
    [switch]$SkipVacationCheck
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[FAIL] This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "[INFO] Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SANDBOX SCHEDULER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$taskNameStart = "Sandbox-AutoStart"
$taskNameStop = "Sandbox-AutoStop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScriptPath = Join-Path $scriptDir "Start-Sandbox.ps1"
$stopScriptPath = Join-Path $scriptDir "Stop-Sandbox.ps1"
$vacationCheckPath = Join-Path $scriptDir "Check-VacationCalendar.ps1"

# Verify scripts exist
if (-not (Test-Path $startScriptPath)) {
    Write-Host "[FAIL] Start-Sandbox.ps1 not found at: $startScriptPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $stopScriptPath)) {
    Write-Host "[FAIL] Stop-Sandbox.ps1 not found at: $stopScriptPath" -ForegroundColor Red
    exit 1
}

# Check if vacation calendar script exists
$hasVacationCalendar = Test-Path $vacationCheckPath
if ($hasVacationCalendar -and -not $SkipVacationCheck) {
    Write-Host "[INFO] Vacation calendar integration: ENABLED" -ForegroundColor Green
} elseif (-not $hasVacationCalendar) {
    Write-Host "[INFO] Vacation calendar integration: NOT AVAILABLE" -ForegroundColor Gray
}

# Remove existing tasks
if ($Remove) {
    Write-Host "[ACTION] Removing scheduled tasks..." -ForegroundColor Yellow
    
    try {
        Unregister-ScheduledTask -TaskName $taskNameStart -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "[PASS] Removed: $taskNameStart" -ForegroundColor Green
    } catch {
        Write-Host "[INFO] Task not found: $taskNameStart" -ForegroundColor Gray
    }
    
    try {
        Unregister-ScheduledTask -TaskName $taskNameStop -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "[PASS] Removed: $taskNameStop" -ForegroundColor Green
    } catch {
        Write-Host "[INFO] Task not found: $taskNameStop" -ForegroundColor Gray
    }
    
    Write-Host "`n[INFO] Scheduled tasks removed" -ForegroundColor Cyan
    Write-Host "  Your sandbox will no longer start/stop automatically" -ForegroundColor White
    exit 0
}

# Display schedule preview
Write-Host "=== PROPOSED SCHEDULE ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "START TIME: $StartTime" -ForegroundColor Green
Write-Host "STOP TIME: $StopTime" -ForegroundColor Red
Write-Host "WORK DAYS ONLY: $WorkDaysOnly" -ForegroundColor White
Write-Host ""

if ($WorkDaysOnly) {
    Write-Host "Schedule: Monday - Friday" -ForegroundColor White
    Write-Host "  08:00 - START (apps come online)" -ForegroundColor Green
    Write-Host "  18:00 - STOP (apps shut down)" -ForegroundColor Red
    Write-Host "  Weekend: Stopped all weekend" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Running Time: ~50 hours/week (30%)" -ForegroundColor Cyan
    Write-Host "Stopped Time: ~118 hours/week (70%)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Cost Savings:" -ForegroundColor Yellow
    Write-Host "  Without schedule: $39/month (24/7 running)" -ForegroundColor Red
    Write-Host "  With schedule: $12/month (business hours only)" -ForegroundColor Green
    Write-Host "  SAVINGS: $27/month (70%)" -ForegroundColor Green
} else {
    Write-Host "Schedule: 7 days/week" -ForegroundColor White
    Write-Host "  $StartTime - START" -ForegroundColor Green
    Write-Host "  $StopTime - STOP" -ForegroundColor Red
    Write-Host ""
    
    $startHour = [int]($StartTime -split ":")[0]
    $stopHour = [int]($StopTime -split ":")[0]
    $dailyHours = $stopHour - $startHour
    $weeklyHours = $dailyHours * 7
    $percentRunning = [math]::Round(($weeklyHours / 168) * 100)
    
    Write-Host "Running Time: ~$weeklyHours hours/week ($percentRunning%)" -ForegroundColor Cyan
    Write-Host "Stopped Time: ~$((168 - $weeklyHours)) hours/week ($((100 - $percentRunning))%)" -ForegroundColor Cyan
}

Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF] Would create 2 scheduled tasks:" -ForegroundColor Cyan
    Write-Host "  1. $taskNameStart (daily at $StartTime)" -ForegroundColor White
    Write-Host "  2. $taskNameStop (daily at $StopTime)" -ForegroundColor White
    exit 0
}

# Confirm
Write-Host "[CONFIRM] Create these scheduled tasks?" -ForegroundColor Yellow
$response = Read-Host "Type 'YES' to proceed"

if ($response -ne "YES") {
    Write-Host "`n[CANCELLED] No tasks created" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n[ACTION] Creating scheduled tasks..." -ForegroundColor Cyan

# Create START task
Write-Host "`n  Creating: $taskNameStart..." -ForegroundColor White

# Build command with vacation calendar check if available
if ($hasVacationCalendar -and -not $SkipVacationCheck) {
    $startArgument = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$vacationCheckPath'; if (`$LASTEXITCODE -eq 0) { & '$startScriptPath' } else { Write-Host '[SKIP] Vacation/Holiday - Auto-start cancelled' -ForegroundColor Yellow }`""
} else {
    $startArgument = "-NoProfile -ExecutionPolicy Bypass -File `"$startScriptPath`""
}

$actionStart = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $startArgument
$triggerStart = New-ScheduledTaskTrigger -Daily -At $StartTime

if ($WorkDaysOnly) {
    # Mon-Fri only
    $triggerStart.DaysOfWeek = [System.DayOfWeek]::Monday, [System.DayOfWeek]::Tuesday, [System.DayOfWeek]::Wednesday, [System.DayOfWeek]::Thursday, [System.DayOfWeek]::Friday
}

$principalStart = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settingsStart = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $taskNameStart -Action $actionStart -Trigger $triggerStart -Principal $principalStart -Settings $settingsStart -Description "Auto-start sandbox compute resources at $StartTime" | Out-Null

Write-Host "  [PASS] $taskNameStart created" -ForegroundColor Green

# Create STOP task
Write-Host "`n  Creating: $taskNameStop..." -ForegroundColor White

# Build command with vacation calendar check if available
if ($hasVacationCalendar -and -not $SkipVacationCheck) {
    $stopArgument = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$vacationCheckPath'; if (`$LASTEXITCODE -eq 0) { & '$stopScriptPath' -Force } else { Write-Host '[SKIP] Vacation/Holiday - Auto-stop cancelled' -ForegroundColor Yellow }`""
} else {
    $stopArgument = "-NoProfile -ExecutionPolicy Bypass -File `"$stopScriptPath`" -Force"
}

$actionStop = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $stopArgument
$triggerStop = New-ScheduledTaskTrigger -Daily -At $StopTime

if ($WorkDaysOnly) {
    # Mon-Fri only
    $triggerStop.DaysOfWeek = [System.DayOfWeek]::Monday, [System.DayOfWeek]::Tuesday, [System.DayOfWeek]::Wednesday, [System.DayOfWeek]::Thursday, [System.DayOfWeek]::Friday
}

$principalStop = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settingsStop = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $taskNameStop -Action $actionStop -Trigger $triggerStop -Principal $principalStop -Settings $settingsStop -Description "Auto-stop sandbox compute resources at $StopTime" | Out-Null

Write-Host "  [PASS] $taskNameStop created" -ForegroundColor Green

# Verify tasks
Write-Host "`n=== VERIFICATION ===" -ForegroundColor Cyan

$tasks = Get-ScheduledTask -TaskName "Sandbox-*" -ErrorAction SilentlyContinue

if ($tasks) {
    $tasks | Select-Object TaskName, State, @{Name='NextRunTime';Expression={$_.NextRunTime}} | Format-Table -AutoSize
    Write-Host "[PASS] Scheduled tasks created successfully" -ForegroundColor Green
} else {
    Write-Host "[WARN] Could not verify tasks" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  SCHEDULER SETUP COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Your sandbox will now:" -ForegroundColor Cyan
Write-Host "  - START automatically at $StartTime" -ForegroundColor Green
if ($WorkDaysOnly) {
    Write-Host "  - STOP automatically at $StopTime" -ForegroundColor Red
    Write-Host "  - Stay stopped all weekend" -ForegroundColor Gray
} else {
    Write-Host "  - STOP automatically at $StopTime" -ForegroundColor Red
}
Write-Host ""

Write-Host "MANUAL OVERRIDE:" -ForegroundColor Yellow
Write-Host "  Start now: .\Start-Sandbox.ps1" -ForegroundColor White
Write-Host "  Stop now: .\Stop-Sandbox.ps1" -ForegroundColor White
Write-Host "  Remove schedule: .\Schedule-Sandbox.ps1 -Remove" -ForegroundColor White
Write-Host ""

Write-Host "VIEW SCHEDULE:" -ForegroundColor Cyan
Write-Host "  Task Scheduler > Task Scheduler Library > Sandbox-AutoStart" -ForegroundColor White
Write-Host "  Task Scheduler > Task Scheduler Library > Sandbox-AutoStop" -ForegroundColor White
Write-Host ""

# Save schedule to file
$scheduleConfig = @{
    created = Get-Date -Format "o"
    start_time = $StartTime
    stop_time = $StopTime
    work_days_only = $WorkDaysOnly
    estimated_monthly_savings = if ($WorkDaysOnly) { 27 } else { [math]::Round(((168 - $weeklyHours) / 168) * 39) }
} | ConvertTo-Json

$configFile = ".\sandbox-schedule-config.json"
Set-Content -Path $configFile -Value $scheduleConfig
Write-Host "[INFO] Schedule configuration saved to: $configFile" -ForegroundColor Gray
