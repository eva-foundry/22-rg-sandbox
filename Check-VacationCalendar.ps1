# Check-VacationCalendar.ps1
# Helper function to check if today is a vacation/holiday/skip date

param(
    [DateTime]$CheckDate = (Get-Date),
    [string]$CalendarFile = "$PSScriptRoot\vacation-calendar.txt"
)

function Test-IsVacationDay {
    param(
        [DateTime]$Date,
        [string]$CalendarPath
    )
    
    if (-not (Test-Path $CalendarPath)) {
        Write-Host "[WARN] Calendar file not found: $CalendarPath" -ForegroundColor Yellow
        return @{
            IsVacation = $false
            Reason = "Calendar file not found"
        }
    }
    
    $dateString = $Date.ToString("yyyy-MM-dd")
    
    # Read calendar file
    $lines = Get-Content $CalendarPath | Where-Object {
        $_ -match '^\d{4}-\d{2}-\d{2}' -and $_ -notmatch '^#'
    }
    
    foreach ($line in $lines) {
        # Parse line: YYYY-MM-DD | Type | Description
        if ($line -match '^(\d{4}-\d{2}-\d{2})\s*\|\s*(\w+)\s*\|\s*(.+)$') {
            $calDate = $matches[1]
            $type = $matches[2].Trim()
            $description = $matches[3].Trim()
            
            if ($calDate -eq $dateString) {
                return @{
                    IsVacation = $true
                    Type = $type
                    Description = $description
                    Date = $calDate
                }
            }
        }
    }
    
    return @{
        IsVacation = $false
        Reason = "Normal working day"
    }
}

# Main execution
$result = Test-IsVacationDay -Date $CheckDate -CalendarPath $CalendarFile

if ($result.IsVacation) {
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  VACATION/HOLIDAY DETECTED" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  Date: $($result.Date)" -ForegroundColor White
    Write-Host "  Type: $($result.Type)" -ForegroundColor White
    Write-Host "  Reason: $($result.Description)" -ForegroundColor White
    Write-Host "`n[ACTION] Auto-start/stop should be SKIPPED today" -ForegroundColor Cyan
    exit 1  # Exit code 1 = Skip operation
} else {
    Write-Host "[INFO] $(Get-Date -Format 'yyyy-MM-dd'): $($result.Reason)" -ForegroundColor Green
    exit 0  # Exit code 0 = Proceed normally
}
