<#
.SYNOPSIS
    KBU PC Inventory Tool
    Automated hardware, OS, network, security and health information collector.

.DESCRIPTION
    A professional PowerShell-based IT inventory application that collects
    detailed system information from Windows workstations and generates
    a beautiful, responsive HTML dashboard report.

    This tool is READ-ONLY -- it does NOT modify, install, delete, or configure
    anything on the system.

.NOTES
    Version:      2.2.0
    Author:       KBU IT Department
    Created:      2026-06-25
    License:      MIT
    Requires:     Windows 10 / Windows 11, PowerShell 5.1+
#>
#Requires -Version 5.1

# ============================================================================
# Dot-source modules
# ============================================================================
. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Logger.ps1"
. "$PSScriptRoot\Collectors.ps1"
. "$PSScriptRoot\Network.ps1"
. "$PSScriptRoot\Security.ps1"
. "$PSScriptRoot\ReportRenderer.ps1"
. "$PSScriptRoot\Export.ps1"
. "$PSScriptRoot\Server.ps1"

# ============================================================================
# Main Execution
# ============================================================================

function Main {
    Clear-Host

    Write-Host "  +=============================================================+" -ForegroundColor Cyan
    Write-Host "  |                                                             |" -ForegroundColor Cyan
    Write-Host "  |    $EmojiMicroscope  KBU PC INVENTORY TOOL                         |" -ForegroundColor Cyan
    Write-Host "  |    Karabuk University IT Department                        |" -ForegroundColor Cyan
    Write-Host "  |    Version: $Script:ToolVersion                                              |" -ForegroundColor Cyan
    Write-Host "  |                                                             |" -ForegroundColor Cyan
    Write-Host "  +=============================================================+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  $([char]0x26A0)  This tool is READ-ONLY -- No system modifications are made." -ForegroundColor Yellow
    Write-Host ""

    # ---------- Phase 1: Collect All Data ----------
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |   PHASE 1: Data Collection              |" -ForegroundColor DarkCyan
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""

    $systemInfo   = Get-SystemInformation
    $cpuInfo      = Get-CPUInformation
    $ramInfo      = Get-RAMInformation
    $gpuList      = Get-GPUInformation
    $diskList     = Get-StorageInformation
    $motherboard  = Get-MotherboardInformation
    $biosInfo     = Get-BIOSInformation
    $networkInfo  = Get-NetworkInformation
    $batteryInfo  = Get-BatteryInformation
    $securityInfo = Get-SecurityInformation

    # ---------- Phase 2: Generate Reports ----------
    Write-Host ""
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |   PHASE 2: Generating Reports           |" -ForegroundColor DarkCyan
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan
    Write-Host ""

    Write-Host "  [$([char]0x2192)] Building HTML report..." -ForegroundColor Cyan

    $htmlReport = Build-HtmlReport `
        -SystemInfo    $systemInfo `
        -CPUInfo       $cpuInfo `
        -RAMInfo       $ramInfo `
        -GPUList       $gpuList `
        -DiskList      $diskList `
        -Motherboard   $motherboard `
        -BIOSInfo      $biosInfo `
        -NetworkInfo   $networkInfo `
        -BatteryInfo   $batteryInfo `
        -SecurityInfo  $securityInfo

    Write-Host "  [$([char]0x2192)] Exporting JSON report..." -ForegroundColor Cyan

    $inventoryData = [PSCustomObject]@{
        metadata = [PSCustomObject]@{
            tool_version  = $Script:ToolVersion
            scan_date     = $Script:ScanDate
            computer_name = $Script:ComputerName
            current_user  = $Script:CurrentUser
        }
        system      = $systemInfo
        cpu         = $cpuInfo
        ram         = $ramInfo
        gpu         = $gpuList
        disk        = $diskList
        motherboard = $motherboard
        bios        = $biosInfo
        network     = $networkInfo
        battery     = $batteryInfo
        security    = $securityInfo
    }

    Export-InventoryJson `
        -InventoryData $inventoryData `
        -OutputPath    $Script:OutputPath `
        -FileName      $Script:ReportFilename

    try {
        $htmlReport | Out-File -FilePath $Script:ReportPath -Encoding UTF8 -Force
        Write-Host "  $([char]0x2713) HTML report saved to $Script:ReportPath" -ForegroundColor Green
    }
    catch {
        Write-Host "  [$([char]0x26A0)] WARNING: Could not save HTML report to $Script:ReportPath" -ForegroundColor Yellow
    }

    # ---------- Phase 3: Start Live Server ----------
    Write-Host ""
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |   PHASE 3: Live Server Mode             |" -ForegroundColor DarkCyan
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan

    Start-KBUHttpServer `
        -SystemInfo    $systemInfo `
        -CPUInfo       $cpuInfo `
        -RAMInfo       $ramInfo `
        -GPUList       $gpuList `
        -DiskList      $diskList `
        -Motherboard   $motherboard `
        -BIOSInfo      $biosInfo `
        -NetworkInfo   $networkInfo `
        -BatteryInfo   $batteryInfo `
        -SecurityInfo  $securityInfo `
        -InitialHtml   $htmlReport

    # ---------- Phase 4: Open in Browser (after server stops) ----------
    if ($Script:AutoOpen) {
        Write-Host "  [$([char]0x2192)] Opening report in default browser..." -ForegroundColor Cyan
        try {
            Start-Process -FilePath $Script:ReportPath -ErrorAction Stop
            Write-Host "  [$([char]0x2713)] Browser launched." -ForegroundColor Green
        }
        catch {
            Write-Host "  [!] Could not open browser automatically." -ForegroundColor Yellow
            Write-Host "       Please open the file manually: $Script:ReportPath" -ForegroundColor Yellow
        }
    }

    # ---------- Summary Output ----------
    Write-Host ""
    Write-Host "  +-----------------------------------------+" -ForegroundColor Green
    Write-Host "  |   $EmojiCheck Report Complete!               |" -ForegroundColor Green
    Write-Host "  +-----------------------------------------+" -ForegroundColor Green
    Write-Host ""

    Write-Host "  ----------- Quick Summary -----------" -ForegroundColor DarkCyan
    $consoleGPU = if ($gpuList.Count -gt 0) {
        $dedicatedGpu = @($gpuList) | Where-Object { $_.GPUName -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX|RX\s*\d" } | Select-Object -First 1
        if ($dedicatedGpu) { $dedicatedGpu.GPUName } else { $gpuList[0].GPUName }
    } else { "Not Available" }

    Write-Host "  CPU       : $($cpuInfo.CPUName)" -ForegroundColor White
    Write-Host "  RAM       : $($ramInfo.TotalRAM)" -ForegroundColor White
    Write-Host "  GPU       : $consoleGPU" -ForegroundColor White
    Write-Host "  Windows   : $($systemInfo.WindowsEdition)" -ForegroundColor White
    Write-Host "  Internet  : $($networkInfo.InternetStatus)" -ForegroundColor White
    Write-Host "  --------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""

    Write-Host "  Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Entry point
Main
