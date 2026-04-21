param ($cycleID)

. "$PSScriptRoot\common-log.ps1"

$ffsExe = "C:\Program Files\FreeFileSync\FreeFileSync.exe"
$batch  = "D:\Photo_Workspace\Scripts\sync_mobile_to_laptop.ffs_batch"

Write-Host "`n[STEP 1] Phone → Laptop"

# ── Validate paths ───────────────────────────────────────────────────────────
if (!(Test-Path $ffsExe)) {
    $msg = "FreeFileSync not found at: $ffsExe"
    Write-Host "  ✗ $msg" -ForegroundColor Red
    Update-Step $cycleID "PhoneToLaptop" "FAILED"
    Add-EventLog $cycleID "PhoneToLaptop" "FAILED" $msg
    exit 2
}

if (!(Test-Path $batch)) {
    $msg = "Batch file not found at: $batch"
    Write-Host "  ✗ $msg" -ForegroundColor Red
    Update-Step $cycleID "PhoneToLaptop" "FAILED"
    Add-EventLog $cycleID "PhoneToLaptop" "FAILED" $msg
    exit 2
}

# ── Check phone connectivity via Windows MTP/WPD ─────────────────────────────
$phone = Get-WmiObject Win32_PnPEntity |
         Where-Object { 
             $_.PNPClass -eq 'WPD' -and 
             $_.Status   -eq 'OK'  -and 
             $_.PNPDeviceID -like 'USB\*' 
         }

if ($null -eq $phone -or @($phone).Count -eq 0) {
    $msg = "Phone not connected — no MTP device detected on USB"
    Write-Host "  ⚠ $msg" -ForegroundColor Yellow
    Update-Step $cycleID "PhoneToLaptop" "SKIPPED"
    Add-EventLog $cycleID "PhoneToLaptop" "SKIPPED" $msg
    exit 1
}

Write-Host "  ✓ Phone detected: $(@($phone)[0].Name)" -ForegroundColor Green

# ── Run FreeFileSync silently ─────────────────────────────────────────────────
try {
    Write-Host "  Syncing..." -ForegroundColor Gray
    $proc = Start-Process -FilePath $ffsExe -ArgumentList $batch -Wait -PassThru
    $code = $proc.ExitCode

    switch ($code) {
        0 {
            Write-Host "  ✓ Sync completed successfully" -ForegroundColor Green
            Update-Step $cycleID "PhoneToLaptop" "SUCCESS"
            Add-EventLog $cycleID "PhoneToLaptop" "SUCCESS" "FreeFileSync completed"
            exit 0
        }
        1 {
            Write-Host "  ⚠ Sync completed with warnings (some files may be skipped)" -ForegroundColor Yellow
            Update-Step $cycleID "PhoneToLaptop" "WARNING"
            Add-EventLog $cycleID "PhoneToLaptop" "WARNING" "FreeFileSync exit code 1 — warnings"
            exit 1
        }
        2 {
            Write-Host "  ⚠ Sync completed with errors (some files failed to copy)" -ForegroundColor Yellow
            Update-Step $cycleID "PhoneToLaptop" "WARNING"
            Add-EventLog $cycleID "PhoneToLaptop" "WARNING" "FreeFileSync exit code 2 — errors"
            exit 1
        }
        3 {
            Write-Host "  ✗ Sync aborted — FreeFileSync was interrupted" -ForegroundColor Red
            Update-Step $cycleID "PhoneToLaptop" "FAILED"
            Add-EventLog $cycleID "PhoneToLaptop" "FAILED" "FreeFileSync exit code 3 — aborted"
            exit 2
        }
        default {
            Write-Host "  ✗ Unexpected exit code: $code" -ForegroundColor Red
            Update-Step $cycleID "PhoneToLaptop" "FAILED"
            Add-EventLog $cycleID "PhoneToLaptop" "FAILED" "Unexpected exit code: $code"
            exit 2
        }
    }
}
catch {
    Write-Host "  ✗ Exception: $_" -ForegroundColor Red
    Update-Step $cycleID "PhoneToLaptop" "FAILED"
    Add-EventLog $cycleID "PhoneToLaptop" "FAILED" "$_"
    exit 
}