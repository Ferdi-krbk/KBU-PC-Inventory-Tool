﻿﻿<#
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
    Version:      1.0.0
    Author:       KBU IT Department
    Created:      2026-06-25
    License:      MIT
    Requires:     Windows 10 / Windows 11, PowerShell 5.1+
#>

#Requires -Version 5.1

# ============================================================================
# REGION: Unicode Character Definitions (ASCII-safe approach)
# ============================================================================

# All emoji/Unicode characters defined here to avoid encoding issues
$EmojiCheck     = [char]0x2705                     # White Heavy Check Mark
$EmojiWarn      = [char]0x26A0 + [char]0xFE0F     # Warning Sign
$EmojiSystem    = [char]::ConvertFromUtf32(0x1F5A5) + [char]0xFE0F  # Desktop Computer
$EmojiCpu       = [char]0x2699 + [char]0xFE0F      # Gear
$EmojiRam       = [char]::ConvertFromUtf32(0x1F9E0) # Brain
$EmojiGpu       = [char]::ConvertFromUtf32(0x1F3AE) # Video Game
$EmojiStorage   = [char]::ConvertFromUtf32(0x1F4BE) # Floppy Disk
$EmojiMobo      = [char]::ConvertFromUtf32(0x1F527) # Wrench
$EmojiBios      = [char]::ConvertFromUtf32(0x1F50C) # Electric Plug
$EmojiNetwork   = [char]::ConvertFromUtf32(0x1F310) # Globe with Meridians
$EmojiBattery   = [char]::ConvertFromUtf32(0x1F50B) # Battery
$EmojiSecurity  = [char]::ConvertFromUtf32(0x1F6E1) + [char]0xFE0F  # Shield
$EmojiClipboard = [char]::ConvertFromUtf32(0x1F4CB) # Clipboard
$EmojiSummary   = [char]::ConvertFromUtf32(0x1F4CA) # Bar Chart
$EmojiWindows   = [char]::ConvertFromUtf32(0x1FA9F) # Window
$EmojiMicroscope = [char]::ConvertFromUtf32(0x1F52C) # Microscope
$EmojiPlug      = [char]::ConvertFromUtf32(0x1F50C) # Electric Plug

# ============================================================================
# REGION: Global Configuration & Variables
# ============================================================================

# Get Desktop path with fallback for reliability
$Script:DesktopPath = if ([Environment]::GetFolderPath("Desktop")) {
    [Environment]::GetFolderPath("Desktop")
} else {
    Join-Path -Path $env:USERPROFILE -ChildPath "Desktop"
}
$Script:ReportPath = Join-Path -Path $Script:DesktopPath -ChildPath "KBU_PC_Inventory_Report.html"
$Script:CurrentUser = [System.Environment]::UserName
$Script:ComputerName = [System.Environment]::MachineName
$Script:ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ============================================================================
# REGION: Helper Functions
# ============================================================================

<#
.SYNOPSIS
    Safely executes a script block and returns "Not Available" on any error.
#>
function Invoke-SafeQuery {
    param(
        [string]$Label,
        [scriptblock]$ScriptBlock,
        [string]$DefaultValue = "Not Available"
    )
    try {
        $result = & $ScriptBlock
        if ($null -eq $result -or $result -eq '') {
            return $DefaultValue
        }
        return $result
    }
    catch {
        return $DefaultValue
    }
}

<#
.SYNOPSIS
    Converts a WMI/CIM datetime string to a readable format.
#>
function Convert-WmiDate {
    param([string]$WmiDate)
    if (-not $WmiDate) { return "Not Available" }
    try {
        return [System.Management.ManagementDateTimeConverter]::ToDateTime($WmiDate).ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        return "Not Available"
    }
}

<#
.SYNOPSIS
    Converts bytes to a human-readable size string.
#>
function Format-FileSize {
    param([double]$Bytes)
    if ($Bytes -lt 0) { return "Not Available" }
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "{0:N0} Bytes" -f $Bytes
}

<#
.SYNOPSIS
    Returns a CSS class name for status badge coloring.
#>
function Get-StatusBadgeClass {
    param([string]$Status)
    switch -Regex ($Status.ToLower()) {
        'ok|healthy|enabled|ready|running|online|charged|active|licensed' { return 'badge-ok' }
        'warning|caution|partial|degraded|discharging|not available'    { return 'badge-warn' }
        'error|failed|disabled|stopped|offline|unhealthy|critical'      { return 'badge-error' }
        default                                                           { return 'badge-warn' }
    }
}

<#
.SYNOPSIS
    Returns an emoji icon string for each report section.
#>
function Get-SectionIcon {
    param([string]$Section)
    switch ($Section) {
        'system'      { return $EmojiSystem }
        'cpu'         { return $EmojiCpu }
        'ram'         { return $EmojiRam }
        'gpu'         { return $EmojiGpu }
        'storage'     { return $EmojiStorage }
        'motherboard' { return $EmojiMobo }
        'bios'        { return $EmojiBios }
        'network'     { return $EmojiNetwork }
        'battery'     { return $EmojiBattery }
        'security'    { return $EmojiSecurity }
        default       { return $EmojiClipboard }
    }
}

# ============================================================================
# REGION: Data Collection Functions
# ============================================================================

<#
.SYNOPSIS
    Collects basic OS and system information.
#>
function Get-SystemInformation {
    Write-Host "  [$([char]0x2192)] Collecting System Information..." -ForegroundColor Cyan

    $os = Invoke-SafeQuery -Label "OS Info" -ScriptBlock {
        Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
            Select-Object -First 1
    }

    $uptime = Invoke-SafeQuery -Label "Uptime" -ScriptBlock {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1
        $lastBoot = $osInfo.LastBootUpTime
        if ($lastBoot) {
            $span = (Get-Date) - $lastBoot
            "{0} days, {1:D2}:{2:D2}:{3:D2}" -f $span.Days, $span.Hours, $span.Minutes, $span.Seconds
        }
    }

    return [PSCustomObject]@{
        ComputerName   = $Script:ComputerName
        LoggedInUser   = "$Script:CurrentUser"
        WindowsEdition = Invoke-SafeQuery -Label "Edition" -ScriptBlock { $os.Caption }
        WindowsVersion = Invoke-SafeQuery -Label "Version" -ScriptBlock { $os.Version }
        BuildNumber    = Invoke-SafeQuery -Label "Build" -ScriptBlock { $os.BuildNumber }
        Architecture   = Invoke-SafeQuery -Label "Architecture" -ScriptBlock { $os.OSArchitecture }
        InstallDate    = Convert-WmiDate -WmiDate (Invoke-SafeQuery -Label "InstallDate" -ScriptBlock { $os.InstallDate })
        LastBootTime   = Convert-WmiDate -WmiDate (Invoke-SafeQuery -Label "LastBoot" -ScriptBlock { $os.LastBootUpTime })
        Uptime         = $uptime
    }
}

<#
.SYNOPSIS
    Collects CPU information.
#>
function Get-CPUInformation {
    Write-Host "  [$([char]0x2192)] Collecting CPU Information..." -ForegroundColor Cyan

    $cpu = Invoke-SafeQuery -Label "CPU" -ScriptBlock {
        Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
            Select-Object -First 1
    }

    $cpuUsage = Invoke-SafeQuery -Label "CPU Usage" -ScriptBlock {
        $avg = (Get-Counter -Counter "\Processor(_Total)\% Processor Time" -ErrorAction Stop).CounterSamples.CookedValue
        if ($avg) { "{0:N1}%" -f $avg } else { "Not Available" }
    }

    return [PSCustomObject]@{
        CPUName       = Invoke-SafeQuery -Label "CPU Name" -ScriptBlock { $cpu.Name -replace '\s+', ' ' }
        Manufacturer  = Invoke-SafeQuery -Label "CPU Manufacturer" -ScriptBlock { $cpu.Manufacturer }
        Cores         = Invoke-SafeQuery -Label "Cores" -ScriptBlock { $cpu.NumberOfCores }
        Threads       = Invoke-SafeQuery -Label "Threads" -ScriptBlock { $cpu.NumberOfLogicalProcessors }
        MaxClockSpeed = Invoke-SafeQuery -Label "Max Clock" -ScriptBlock { "$($cpu.MaxClockSpeed) MHz" }
        CurrentUsage  = $cpuUsage
    }
}

<#
.SYNOPSIS
    Collects RAM / Memory information via CIM and SMBIOS.
#>
function Get-RAMInformation {
    Write-Host "  [$([char]0x2192)] Collecting RAM Information..." -ForegroundColor Cyan

    $os = Invoke-SafeQuery -Label "OS Memory" -ScriptBlock {
        Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
            Select-Object -First 1
    }

    $totalRAM = Invoke-SafeQuery -Label "Total RAM" -ScriptBlock {
        [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    }
    $freeRAM = Invoke-SafeQuery -Label "Free RAM" -ScriptBlock {
        [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    }

    $usedRAM = if ($totalRAM -is [double] -and $freeRAM -is [double]) {
        [math]::Round($totalRAM - $freeRAM, 2)
    } else { "Not Available" }

    $modules = Invoke-SafeQuery -Label "RAM Modules" -ScriptBlock {
        Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
    }

    $moduleCount = if ($modules -is [array]) { $modules.Count } elseif ($modules) { 1 } else { 0 }

    $ramModulesInfo = @()
    if ($modules) {
        foreach ($mod in @($modules)) {
            $ramModulesInfo += [PSCustomObject]@{
                Manufacturer = Invoke-SafeQuery -Label "RAM Manufacturer" -ScriptBlock { $mod.Manufacturer }
                PartNumber   = Invoke-SafeQuery -Label "RAM Part Number" -ScriptBlock { $mod.PartNumber }
                Speed        = Invoke-SafeQuery -Label "RAM Speed" -ScriptBlock { "$($mod.Speed) MHz" }
                Capacity     = Invoke-SafeQuery -Label "RAM Capacity" -ScriptBlock { Format-FileSize -Bytes $mod.Capacity }
            }
        }
    }

    return [PSCustomObject]@{
        TotalRAM         = if ($totalRAM -is [double]) { "$totalRAM GB" } else { "Not Available" }
        AvailableRAM     = if ($freeRAM -is [double]) { "$freeRAM GB" } else { "Not Available" }
        UsedRAM          = if ($usedRAM -is [double]) { "$usedRAM GB" } else { "Not Available" }
        InstalledModules = $moduleCount
        Modules          = $ramModulesInfo
    }
}

<#
.SYNOPSIS
    Collects GPU / Video Controller information.
#>
function Get-GPUInformation {
    Write-Host "  [$([char]0x2192)] Collecting GPU Information..." -ForegroundColor Cyan

    $gpus = Invoke-SafeQuery -Label "GPU" -ScriptBlock {
        Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
    }

    $gpuList = @()
    if ($gpus) {
        foreach ($gpu in @($gpus)) {
            $gpuList += [PSCustomObject]@{
                GPUName       = Invoke-SafeQuery -Label "GPU Name" -ScriptBlock { $gpu.Name }
                VRAM          = Invoke-SafeQuery -Label "VRAM" -ScriptBlock {
                    if ($gpu.AdapterRAM) {
                        Format-FileSize -Bytes $gpu.AdapterRAM
                    } else { "Not Available" }
                }
                DriverVersion = Invoke-SafeQuery -Label "Driver Version" -ScriptBlock { $gpu.DriverVersion }
            }
        }
    }

    return $gpuList
}

<#
.SYNOPSIS
    Collects Storage / Disk information including health status.
    Uses pure .NET methods that work 100% reliably without admin privileges.
#>
function Get-StorageInformation {
    Write-Host "  [$([char]0x2192)] Collecting Storage Information..." -ForegroundColor Cyan

    $diskList = @()

    # Use pure .NET DriveInfo -- guaranteed to work on all Windows systems
    $allDrives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }

    foreach ($drive in $allDrives) {
        $totalBytes = $drive.TotalSize
        $freeBytes  = $drive.AvailableFreeSpace
        $usedBytes  = $totalBytes - $freeBytes

        $usagePercent = if ($totalBytes -gt 0) {
            [math]::Round(($usedBytes / $totalBytes) * 100, 1)
        } else { 0 }

        $usageStatus = "OK"
        if ($usagePercent -gt 90) { $usageStatus = "Error" }
        elseif ($usagePercent -gt 75) { $usageStatus = "Warning" }

        $diskList += [PSCustomObject]@{
            DriveLetter   = $drive.Name
            Model         = "Not Available"
            MediaType     = "Not Available"
            InterfaceType = "Not Available"
            Capacity      = Format-FileSize -Bytes $totalBytes
            UsedSpace     = Format-FileSize -Bytes $usedBytes
            FreeSpace     = Format-FileSize -Bytes $freeBytes
            UsagePercent  = $usagePercent
            UsageStatus   = $usageStatus
            HealthStatus  = "Not Available"
        }
    }

    # If .NET also returned nothing, add a placeholder
    if ($diskList.Count -eq 0) {
        $diskList += [PSCustomObject]@{
            DriveLetter   = "N/A"
            Model         = "Not Available"
            MediaType     = "Not Available"
            InterfaceType = "Not Available"
            Capacity      = "Not Available"
            UsedSpace     = "Not Available"
            FreeSpace     = "Not Available"
            UsagePercent  = 0
            UsageStatus   = "OK"
            HealthStatus  = "Not Available"
        }
    }

    return $diskList
}

<#
.SYNOPSIS
    Collects Motherboard / BaseBoard information.
#>
function Get-MotherboardInformation {
    Write-Host "  [$([char]0x2192)] Collecting Motherboard Information..." -ForegroundColor Cyan

    $board = Invoke-SafeQuery -Label "Motherboard" -ScriptBlock {
        Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop |
            Select-Object -First 1
    }

    return [PSCustomObject]@{
        Manufacturer = Invoke-SafeQuery -Label "Board Manufacturer" -ScriptBlock { $board.Manufacturer }
        Model        = Invoke-SafeQuery -Label "Board Model" -ScriptBlock { $board.Product }
        SerialNumber = Invoke-SafeQuery -Label "Board Serial" -ScriptBlock { $board.SerialNumber }
    }
}

<#
.SYNOPSIS
    Collects BIOS information.
#>
function Get-BIOSInformation {
    Write-Host "  [$([char]0x2192)] Collecting BIOS Information..." -ForegroundColor Cyan

    $bios = Invoke-SafeQuery -Label "BIOS" -ScriptBlock {
        Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop |
            Select-Object -First 1
    }

    return [PSCustomObject]@{
        Manufacturer = Invoke-SafeQuery -Label "BIOS Manufacturer" -ScriptBlock { $bios.Manufacturer }
        Version      = Invoke-SafeQuery -Label "BIOS Version" -ScriptBlock { $bios.SMBIOSBIOSVersion }
        ReleaseDate  = Convert-WmiDate -WmiDate (Invoke-SafeQuery -Label "BIOS Release" -ScriptBlock { $bios.ReleaseDate })
    }
}

<#
.SYNOPSIS
    Collects Network adapter and connectivity information.
#>
function Get-NetworkInformation {
    Write-Host "  [$([char]0x2192)] Collecting Network Information..." -ForegroundColor Cyan

    # Find active network adapters
    $adapters = Invoke-SafeQuery -Label "Network Adapters" -ScriptBlock {
        Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "NetEnabled=True AND PhysicalAdapter=True" -ErrorAction Stop
    }

    $netList = @()

    if ($adapters) {
        foreach ($adapter in @($adapters)) {
            $config = Invoke-SafeQuery -Label "Adapter Config" -ScriptBlock {
                Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "Index=$($adapter.Index)" -ErrorAction SilentlyContinue |
                    Select-Object -First 1
            }

            $linkSpeed = Invoke-SafeQuery -Label "Link Speed" -ScriptBlock {
                if ($adapter.Speed -and $adapter.Speed -gt 0) {
                    if ($adapter.Speed -ge 1000000000) {
                        "{0:N0} Gbps" -f ($adapter.Speed / 1000000000)
                    } elseif ($adapter.Speed -ge 1000000) {
                        "{0:N0} Mbps" -f ($adapter.Speed / 1000000)
                    } else {
                        "{0:N0} Kbps" -f ($adapter.Speed / 1000)
                    }
                }
            }

            $ipAddr = Invoke-SafeQuery -Label "IPv4" -ScriptBlock {
                ($config.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }) -join ', '
            }
            $gateway = Invoke-SafeQuery -Label "Gateway" -ScriptBlock {
                ($config.DefaultIPGateway | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }) -join ', '
            }
            $dns = Invoke-SafeQuery -Label "DNS" -ScriptBlock { $config.DNSServerSearchOrder -join ', ' }
            $mac = Invoke-SafeQuery -Label "MAC" -ScriptBlock { $adapter.MACAddress }

            $netList += [PSCustomObject]@{
                AdapterName    = $adapter.Name
                MACAddress     = $mac
                IPv4Address    = $ipAddr
                DefaultGateway = $gateway
                DNSServers     = $dns
                LinkSpeed      = $linkSpeed
            }
        }
    }

    # Internet connectivity check
    $internetStatus = Invoke-SafeQuery -Label "Internet" -ScriptBlock {
        $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ping) { "Connected" } else { "Disconnected" }
    }

    return [PSCustomObject]@{
        Adapters       = $netList
        InternetStatus = $internetStatus
    }
}

<#
.SYNOPSIS
    Collects Battery information (laptops only).
#>
function Get-BatteryInformation {
    Write-Host "  [$([char]0x2192)] Collecting Battery Information..." -ForegroundColor Cyan

    $battery = Invoke-SafeQuery -Label "Battery" -ScriptBlock {
        Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop |
            Select-Object -First 1
    }

    if (-not $battery -or $battery -is [string]) {
        return $null
    }

    $chargePercent = Invoke-SafeQuery -Label "Charge %" -ScriptBlock {
        if ($battery.EstimatedChargeRemaining) { "$($battery.EstimatedChargeRemaining)%" }
    }

    $batteryStatus = Invoke-SafeQuery -Label "Battery Status" -ScriptBlock {
        switch ($battery.BatteryStatus) {
            1  { "Discharging" }
            2  { "On AC Power" }
            3  { "Fully Charged" }
            4  { "Low" }
            5  { "Critical" }
            6  { "Charging" }
            7  { "Charging (High)" }
            8  { "Charging (Low)" }
            9  { "Charging (Critical)" }
            10 { "Undefined" }
            11 { "Partially Charged" }
            default { "Unknown ($($battery.BatteryStatus))" }
        }
    }

    return [PSCustomObject]@{
        BatteryName   = Invoke-SafeQuery -Label "Battery Name" -ScriptBlock { $battery.Name }
        ChargePercent = $chargePercent
        BatteryStatus = $batteryStatus
    }
}

<#
.SYNOPSIS
    Collects Security-related information.
#>
function Get-SecurityInformation {
    Write-Host "  [$([char]0x2192)] Collecting Security Information..." -ForegroundColor Cyan

    # Windows Defender status
    $defenderStatus = Invoke-SafeQuery -Label "Defender" -ScriptBlock {
        try {
            $status = Get-MpComputerStatus -ErrorAction Stop
            if ($status.AntivirusEnabled) { "Enabled" } else { "Disabled" }
        }
        catch {
            "Not Available"
        }
    }

    # Firewall status
    $firewallStatus = Invoke-SafeQuery -Label "Firewall" -ScriptBlock {
        try {
            $fw = Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop |
                Where-Object { $_.Enabled -eq $true }
            if ($fw) { "Enabled" } else { "Disabled" }
        }
        catch {
            "Not Available"
        }
    }

    # Windows Activation status
    $activationStatus = Invoke-SafeQuery -Label "Activation" -ScriptBlock {
        try {
            $lic = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%' AND PartialProductKey IS NOT NULL" -ErrorAction Stop |
                Select-Object -First 1
            switch ($lic.LicenseStatus) {
                0 { "Unlicensed" }
                1 { "Licensed" }
                2 { "OOB Grace" }
                3 { "OOT Grace" }
                4 { "Non-Genuine Grace" }
                5 { "Notification" }
                6 { "Extended Grace" }
                default { "Unknown" }
            }
        }
        catch {
            "Not Available"
        }
    }

    return [PSCustomObject]@{
        WindowsDefender = $defenderStatus
        Firewall        = $firewallStatus
        Activation      = $activationStatus
    }
}

# ============================================================================
# REGION: HTML Report Generation
# ============================================================================

<#
.SYNOPSIS
    Generates a single info row for tables inside cards.
#>
function New-HtmlTableRow {
    param([string]$Label, [string]$Value)
    return @"
                <tr>
                    <td class="info-label">$Label</td>
                    <td class="info-value">$Value</td>
                </tr>
"@
}

<#
.SYNOPSIS
    Generates a status badge span.
#>
function New-HtmlBadge {
    param([string]$Text, [string]$Status)
    $cssClass = Get-StatusBadgeClass -Status $Status
    return "<span class='badge $cssClass'>$Text</span>"
}

<#
.SYNOPSIS
    Builds the complete HTML report from all collected data.
#>
function Build-HtmlReport {
    param(
        $SystemInfo,
        $CPUInfo,
        $RAMInfo,
        $GPUList,
        $DiskList,
        $Motherboard,
        $BIOSInfo,
        $NetworkInfo,
        $BatteryInfo,
        $SecurityInfo
    )

    # ---------- Determine Overall System Status ----------
    $localWarnings = 0
    $localErrors = 0

    # Check disk usage
    foreach ($disk in @($DiskList)) {
        if ($disk.UsageStatus -eq "Error") { $localErrors++ }
        elseif ($disk.UsageStatus -eq "Warning") { $localWarnings++ }
    }

    # Check security (only count truly problematic states)
    if ($SecurityInfo.Activation -ne "Licensed" -and $SecurityInfo.Activation -ne "Not Available") { $localWarnings++ }

    # Check battery
    if ($BatteryInfo) {
        if ($BatteryInfo.BatteryStatus -match "Critical|Low") { $localErrors++ }
        elseif ($BatteryInfo.BatteryStatus -eq "Discharging") { $localWarnings++ }
    }

    # Check internet
    if ($NetworkInfo.InternetStatus -eq "Disconnected") { $localWarnings++ }

    # Find preferred GPU for summary (dedicated GPU takes priority)
    $summaryGPU = if ($GPUList.Count -gt 0) {
        $dedicated = @($GPUList) | Where-Object {
            $_.GPUName -match "NVIDIA|AMD|Radeon|GeForce|RTX|GTX|RX\s*\d"
        } | Select-Object -First 1
        if ($dedicated) { $dedicated.GPUName } else { $GPUList[0].GPUName }
    } else { "Not Available" }

    $overallStatus = if ($localErrors -gt 0) { "Error" } else { "OK" }
    $overallBadge = Get-StatusBadgeClass -Status $overallStatus

    $readyBadge = if ($localErrors -eq 0) {
        "<span class='badge badge-ready'>$EmojiCheck READY FOR DEPLOYMENT</span>"
    } else {
        "<span class='badge badge-error'>$EmojiWarn ISSUES DETECTED -- Review Below</span>"
    }

    # ---------- Build RAM Modules Table ----------
    $ramModulesRows = ""
    if ($RAMInfo.Modules.Count -gt 0) {
        foreach ($mod in $RAMInfo.Modules) {
            $ramModulesRows += New-HtmlTableRow -Label "Module" -Value "$($mod.Manufacturer) -- $($mod.PartNumber) | $($mod.Capacity) @ $($mod.Speed)"
        }
    } else {
        $ramModulesRows = New-HtmlTableRow -Label "Modules" -Value "Not Available"
    }

    # ---------- Build GPU Table ----------
    $gpuRows = ""
    foreach ($gpu in @($GPUList)) {
        $gpuRows += New-HtmlTableRow -Label "GPU" -Value "$($gpu.GPUName)"
        $gpuRows += New-HtmlTableRow -Label "VRAM" -Value $gpu.VRAM
        $gpuRows += New-HtmlTableRow -Label "Driver" -Value $gpu.DriverVersion
        if ($gpu -ne $GPUList[-1]) {
            $gpuRows += @"
                <tr><td colspan="2" class="separator"></td></tr>
"@
        }
    }

    # ---------- Build Storage Cards ----------
    $storageCards = ""
    foreach ($disk in @($DiskList)) {
        $healthBadge = New-HtmlBadge -Text $disk.HealthStatus -Status $disk.HealthStatus
        $usageBadgeColor = if ($disk.UsageStatus -eq "Error") { "progress-error" } elseif ($disk.UsageStatus -eq "Warning") { "progress-warn" } else { "progress-ok" }
        $usagePct = if ($disk.UsagePercent -is [double]) { $disk.UsagePercent } else { 0 }

        $storageCards += @"
            <div class="storage-item">
                <div class="storage-header">$EmojiStorage Drive $($disk.DriveLetter)</div>
                <table class="info-table">
                    <tr><td class="info-label">Model</td><td class="info-value">$($disk.Model)</td></tr>
                    <tr><td class="info-label">Type</td><td class="info-value">$($disk.MediaType) ($($disk.InterfaceType))</td></tr>
                    <tr><td class="info-label">Capacity</td><td class="info-value">$($disk.Capacity)</td></tr>
                    <tr><td class="info-label">Used</td><td class="info-value">$($disk.UsedSpace)</td></tr>
                    <tr><td class="info-label">Free</td><td class="info-value">$($disk.FreeSpace)</td></tr>
                    <tr><td class="info-label">Health</td><td class="info-value">$healthBadge</td></tr>
                </table>
                <div class="progress-bar">
                    <div class="progress-fill $usageBadgeColor" style="width: $usagePct%"></div>
                </div>
                <div class="progress-label">$usagePct% Used</div>
            </div>
"@
    }

    # ---------- Build Network Adapter Cards ----------
    $networkCards = ""
    $internetBadge = New-HtmlBadge -Text $NetworkInfo.InternetStatus -Status $NetworkInfo.InternetStatus
    foreach ($adapter in @($NetworkInfo.Adapters)) {
        $networkCards += @"
            <div class="storage-item">
                <div class="storage-header">$EmojiPlug $($adapter.AdapterName)</div>
                <table class="info-table">
                    <tr><td class="info-label">MAC Address</td><td class="info-value mono">$($adapter.MACAddress)</td></tr>
                    <tr><td class="info-label">IPv4 Address</td><td class="info-value mono">$($adapter.IPv4Address)</td></tr>
                    <tr><td class="info-label">Default Gateway</td><td class="info-value mono">$($adapter.DefaultGateway)</td></tr>
                    <tr><td class="info-label">DNS Servers</td><td class="info-value mono">$($adapter.DNSServers)</td></tr>
                    <tr><td class="info-label">Link Speed</td><td class="info-value">$($adapter.LinkSpeed)</td></tr>
                </table>
            </div>
"@
    }

    # ---------- Security Status ----------
    $defenderBadge  = New-HtmlBadge -Text $SecurityInfo.WindowsDefender -Status $SecurityInfo.WindowsDefender
    $firewallBadge  = New-HtmlBadge -Text $SecurityInfo.Firewall -Status $SecurityInfo.Firewall
    $activationBadge = New-HtmlBadge -Text $SecurityInfo.Activation -Status $SecurityInfo.Activation

    # ---------- Battery Section (if present) ----------
    $batterySection = ""
    if ($BatteryInfo) {
        $batteryIcon = Get-SectionIcon "battery"
        $chargeBadge = if ($BatteryInfo.ChargePercent -match '^(\d+)%$') {
            $pct = [int]$Matches[1]
            if ($pct -gt 80) { New-HtmlBadge -Text $BatteryInfo.ChargePercent -Status "OK" }
            elseif ($pct -gt 25) { New-HtmlBadge -Text $BatteryInfo.ChargePercent -Status "Warning" }
            else { New-HtmlBadge -Text $BatteryInfo.ChargePercent -Status "Error" }
        } else {
            New-HtmlBadge -Text $BatteryInfo.ChargePercent -Status "Not Available"
        }
        $statusBadge = New-HtmlBadge -Text $BatteryInfo.BatteryStatus -Status $BatteryInfo.BatteryStatus

        $batterySection = @"
        <!-- Battery Card -->
        <div class="card">
            <div class="card-header">$batteryIcon Battery</div>
            <div class="card-body">
                <table class="info-table">
                    $((New-HtmlTableRow -Label "Battery Name" -Value $BatteryInfo.BatteryName))
                    $((New-HtmlTableRow -Label "Charge %" -Value $chargeBadge))
                    $((New-HtmlTableRow -Label "Status" -Value $statusBadge))
                </table>
            </div>
        </div>
"@
    }

    # ---------- Assemble Full HTML ----------
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>KBU PC Inventory Report -- $Script:ComputerName</title>
    <style>
        /* ============================================
           KBU PC Inventory Tool -- Embedded Stylesheet
           ============================================ */

        /* Reset & Base */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #0f1923;
            color: #e0e6ed;
            min-height: 100vh;
            line-height: 1.6;
        }

        /* Header / Hero */
        .hero {
            background: linear-gradient(135deg, #0a1628 0%, #13203d 50%, #1a2d4a 100%);
            border-bottom: 3px solid #00b4d8;
            padding: 32px 24px;
            text-align: center;
        }
        .hero h1 {
            font-size: 2.2rem;
            font-weight: 700;
            color: #ffffff;
            letter-spacing: -0.5px;
            margin-bottom: 4px;
        }
        .hero .subtitle {
            font-size: 0.95rem;
            color: #90e0ef;
            letter-spacing: 2px;
            text-transform: uppercase;
        }
        .hero .scan-info {
            margin-top: 10px;
            font-size: 0.85rem;
            color: #9aa4b2;
        }

        /* Container */
        .container {
            max-width: 1320px;
            margin: 0 auto;
            padding: 28px 20px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
            gap: 22px;
        }

        /* Summary section at top (full width) */
        .summary-row {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 16px;
            margin-bottom: 8px;
        }

        .summary-card {
            background: linear-gradient(145deg, #1a2d3d, #142130);
            border: 1px solid #2a3f55;
            border-radius: 12px;
            padding: 20px 16px;
            text-align: center;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .summary-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(0, 180, 216, 0.12);
        }
        .summary-card .summary-icon { font-size: 2rem; margin-bottom: 8px; }
        .summary-card .summary-label { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1.5px; color: #7c8da0; margin-bottom: 6px; }
        .summary-card .summary-value { font-size: 1.05rem; font-weight: 600; color: #e0e6ed; word-break: break-word; }

        /* Cards */
        .card {
            background: linear-gradient(145deg, #1a2d3d, #142130);
            border: 1px solid #2a3f55;
            border-radius: 12px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
        }
        .card-header {
            background: rgba(0, 180, 216, 0.08);
            border-bottom: 1px solid #2a3f55;
            padding: 14px 20px;
            font-size: 1rem;
            font-weight: 700;
            color: #00b4d8;
            letter-spacing: 0.5px;
        }
        .card-body {
            padding: 16px 20px;
            flex: 1;
        }

        /* Full-width cards */
        .card-full {
            grid-column: 1 / -1;
        }

        /* Info Tables */
        .info-table { width: 100%; border-collapse: collapse; }
        .info-table tr:not(:last-child) { border-bottom: 1px solid rgba(42, 63, 85, 0.4); }
        .info-table td { padding: 10px 4px; vertical-align: middle; }
        .info-label {
            font-size: 0.82rem;
            font-weight: 600;
            color: #7c8da0;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            width: 160px;
            white-space: nowrap;
        }
        .info-value { font-size: 0.92rem; color: #d4dce6; word-break: break-word; }
        .separator td { padding: 0; border-bottom: 1px dashed #2a3f55; height: 1px; }
        .mono { font-family: 'Consolas', 'Courier New', monospace; font-size: 0.85rem; }

        /* Badges */
        .badge {
            display: inline-block;
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 0.78rem;
            font-weight: 600;
            letter-spacing: 0.4px;
            white-space: nowrap;
        }
        .badge-ok     { background: #064e3b; color: #6ee7b7; border: 1px solid #065f46; }
        .badge-warn   { background: #5c4b00; color: #fde68a; border: 1px solid #7c5e00; }
        .badge-error  { background: #5b1a1a; color: #fca5a5; border: 1px solid #7f1d1d; }
        .badge-ready  {
            background: linear-gradient(135deg, #064e3b, #047857);
            color: #d1fae5;
            border: 2px solid #10b981;
            font-size: 0.95rem;
            padding: 8px 24px;
            letter-spacing: 1px;
            animation: pulse-glow 2s infinite;
        }
        @keyframes pulse-glow {
            0%, 100% { box-shadow: 0 0 8px rgba(16, 185, 129, 0.3); }
            50%      { box-shadow: 0 0 20px rgba(16, 185, 129, 0.6); }
        }

        /* Progress Bar */
        .progress-bar {
            background: #0f1923;
            border-radius: 10px;
            height: 10px;
            margin-top: 12px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            border-radius: 10px;
            transition: width 0.5s ease;
        }
        .progress-ok    { background: linear-gradient(90deg, #10b981, #34d399); }
        .progress-warn  { background: linear-gradient(90deg, #f59e0b, #fbbf24); }
        .progress-error { background: linear-gradient(90deg, #ef4444, #f87171); }
        .progress-label { font-size: 0.75rem; color: #7c8da0; margin-top: 4px; text-align: right; }

        /* Storage Items */
        .storage-item {
            background: rgba(15, 25, 35, 0.5);
            border: 1px solid #2a3f55;
            border-radius: 8px;
            padding: 14px 16px;
            margin-bottom: 12px;
        }
        .storage-header {
            font-weight: 700;
            color: #e0e6ed;
            font-size: 0.95rem;
            margin-bottom: 8px;
        }

        /* Overall Status */
        .status-banner {
            text-align: center;
            padding: 20px;
            margin-bottom: 8px;
        }

        /* Footer */
        .footer {
            text-align: center;
            padding: 28px 20px;
            color: #4a5d70;
            font-size: 0.8rem;
            border-top: 1px solid #1a2d3d;
            margin-top: 20px;
        }

        /* Responsive */
        @media (max-width: 768px) {
            .container { grid-template-columns: 1fr; padding: 14px 10px; gap: 14px; }
            .hero h1 { font-size: 1.5rem; }
            .summary-row { grid-template-columns: repeat(2, 1fr); }
            .info-label { width: 110px; font-size: 0.7rem; }
            .info-value { font-size: 0.8rem; }
        }
        @media (max-width: 480px) {
            .summary-row { grid-template-columns: 1fr; }
            .hero { padding: 20px 12px; }
            .hero h1 { font-size: 1.3rem; }
        }

        /* Refresh Button */
        .refresh-btn {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 12px 28px;
            background: linear-gradient(135deg, #00b4d8, #0077b6);
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 0.95rem;
            font-weight: 700;
            cursor: pointer;
            letter-spacing: 0.5px;
            transition: all 0.2s ease;
            box-shadow: 0 4px 15px rgba(0, 180, 216, 0.3);
        }
        .refresh-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(0, 180, 216, 0.5);
        }
        .refresh-btn:active {
            transform: translateY(0);
        }
        .refresh-btn.loading {
            pointer-events: none;
            opacity: 0.7;
        }
        .refresh-spinner {
            display: none;
            width: 18px; height: 18px;
            border: 3px solid rgba(255,255,255,0.3);
            border-top-color: #fff;
            border-radius: 50%;
            animation: spinner-rotate 0.7s linear infinite;
        }
        .refresh-btn.loading .refresh-spinner { display: inline-block; }
        .refresh-btn.loading .refresh-icon { display: none; }
        @keyframes spinner-rotate {
            to { transform: rotate(360deg); }
        }
        .toast {
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: #064e3b;
            color: #6ee7b7;
            padding: 10px 24px;
            border-radius: 8px;
            font-size: 0.9rem;
            font-weight: 600;
            z-index: 9999;
            opacity: 0;
            transition: opacity 0.3s ease;
            pointer-events: none;
            border: 1px solid #10b981;
        }
        .toast.show { opacity: 1; }
        .toast.error { background: #5b1a1a; color: #fca5a5; border-color: #ef4444; }

        /* Print */
        @media print {
            body { background: #fff; color: #111; }
            .card, .summary-card, .storage-item { background: #f9fafb; border: 1px solid #ccc; }
            .card-header { background: #e5e7eb; color: #111; }
            .badge { border: 1px solid #666 !important; }
            .refresh-btn, .toast { display: none !important; }
        }
    </style>
</head>
<body>

    <!-- ===== HERO / HEADER ===== -->
    <div class="hero">
        <h1>$EmojiMicroscope KBU PC Inventory Tool</h1>
        <div class="subtitle">System Diagnostics & Inventory Report</div>
        <div class="scan-info">
            Computer: <strong>$Script:ComputerName</strong> &nbsp;|&nbsp;
            User: <strong>$Script:CurrentUser</strong> &nbsp;|&nbsp;
            Scanned: <strong>$Script:ScanDate</strong>
        </div>
    </div>

    <!-- ===== STATUS BANNER ===== -->
    <div class="status-banner">
        $readyBadge
    </div>

    <!-- ===== REFRESH BUTTON ===== -->
    <div class="status-banner" style="padding-top:0;">
        <button class="refresh-btn" id="btnRefresh" onclick="refreshReport()">
            <span class="refresh-icon">$([char]::ConvertFromUtf32(0x1F504))</span>
            <span class="refresh-spinner"></span>
            Refresh Report
        </button>
    </div>

    <!-- Toast notification -->
    <div class="toast" id="toast"></div>

    <!-- ===== SYSTEM SUMMARY ROW ===== -->
    <div class="container" style="margin-bottom:0;">
        <div class="card card-full">
            <div class="card-header">$EmojiSummary System Summary</div>
            <div class="card-body">
                <div class="summary-row">
                    <div class="summary-card">
                        <div class="summary-icon">$EmojiCpu</div>
                        <div class="summary-label">CPU</div>
                        <div class="summary-value">$($CPUInfo.CPUName)</div>
                    </div>
                    <div class="summary-card">
                        <div class="summary-icon">$EmojiRam</div>
                        <div class="summary-label">Total RAM</div>
                        <div class="summary-value">$($RAMInfo.TotalRAM)</div>
                    </div>
                    <div class="summary-card">
                        <div class="summary-icon">$EmojiGpu</div>
                        <div class="summary-label">GPU</div>
                        <div class="summary-value">$summaryGPU</div>
                    </div>
                    <div class="summary-card">
                        <div class="summary-icon">$EmojiStorage</div>
                        <div class="summary-label">Disk</div>
                        <div class="summary-value">$(if (@($DiskList).Count -gt 0) { $d = $DiskList[0]; if ($d.MediaType -ne "Not Available") { "$($d.Capacity) ($($d.MediaType))" } else { $d.Capacity } } else { "Not Available" })</div>
                    </div>
                    <div class="summary-card">
                        <div class="summary-icon">$EmojiWindows</div>
                        <div class="summary-label">Windows</div>
                        <div class="summary-value">$($SystemInfo.WindowsEdition)</div>
                    </div>
                    <div class="summary-card">
                        <div class="summary-icon">$EmojiClipboard</div>
                        <div class="summary-label">Overall Status</div>
                        <div class="summary-value">$(New-HtmlBadge -Text $overallStatus.ToUpper() -Status $overallStatus)</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- ===== MAIN CARDS GRID ===== -->
    <div class="container">

        <!-- System Card -->
        <div class="card">
            <div class="card-header">$EmojiSystem System Information</div>
            <div class="card-body">
                <table class="info-table">
                    $((New-HtmlTableRow -Label "Computer Name" -Value $SystemInfo.ComputerName))
                    $((New-HtmlTableRow -Label "Logged-in User" -Value $SystemInfo.LoggedInUser))
                    $((New-HtmlTableRow -Label "Windows Edition" -Value $SystemInfo.WindowsEdition))
                    $((New-HtmlTableRow -Label "Version" -Value $SystemInfo.WindowsVersion))
                    $((New-HtmlTableRow -Label "Build Number" -Value $SystemInfo.BuildNumber))
                    $((New-HtmlTableRow -Label "Architecture" -Value $SystemInfo.Architecture))
                    $((New-HtmlTableRow -Label "Install Date" -Value $SystemInfo.InstallDate))
                    $((New-HtmlTableRow -Label "Last Boot Time" -Value $SystemInfo.LastBootTime))
                    $((New-HtmlTableRow -Label "Uptime" -Value $SystemInfo.Uptime))
                </table>
            </div>
        </div>

        <!-- CPU Card -->
        <div class="card">
            <div class="card-header">$EmojiCpu CPU</div>
            <div class="card-body">
                <table class="info-table">
                    $((New-HtmlTableRow -Label "Name" -Value $CPUInfo.CPUName))
                    $((New-HtmlTableRow -Label "Manufacturer" -Value $CPUInfo.Manufacturer))
                    $((New-HtmlTableRow -Label "Cores" -Value $CPUInfo.Cores))
                    $((New-HtmlTableRow -Label "Threads" -Value $CPUInfo.Threads))
                    $((New-HtmlTableRow -Label "Max Clock Speed" -Value $CPUInfo.MaxClockSpeed))
                    $((New-HtmlTableRow -Label "Current Usage" -Value $CPUInfo.CurrentUsage))
                </table>
            </div>
        </div>

        <!-- RAM Card -->
        <div class="card">
            <div class="card-header">$EmojiRam RAM (Memory)</div>
            <div class="card-body">
                <table class="info-table">
                    $((New-HtmlTableRow -Label "Total RAM" -Value $RAMInfo.TotalRAM))
                    $((New-HtmlTableRow -Label "Available RAM" -Value $RAMInfo.AvailableRAM))
                    $((New-HtmlTableRow -Label "Used RAM" -Value $RAMInfo.UsedRAM))
                    $((New-HtmlTableRow -Label "Installed Modules" -Value $RAMInfo.InstalledModules))
                    $ramModulesRows
                </table>
            </div>
        </div>

        <!-- GPU Card -->
        <div class="card">
            <div class="card-header">$EmojiGpu GPU (Graphics)</div>
            <div class="card-body">
                <table class="info-table">
                    $gpuRows
                </table>
            </div>
        </div>

        <!-- Motherboard Card -->
        <div class="card">
            <div class="card-header">$EmojiMobo Motherboard</div>
            <div class="card-body">
                <table class="info-table">
                    $((New-HtmlTableRow -Label "Manufacturer" -Value $Motherboard.Manufacturer))
                    $((New-HtmlTableRow -Label "Model" -Value $Motherboard.Model))
                    $((New-HtmlTableRow -Label "Serial Number" -Value $Motherboard.SerialNumber))
                </table>
            </div>
        </div>

        <!-- BIOS Card -->
        <div class="card">
            <div class="card-header">$EmojiBios BIOS</div>
            <div class="card-body">
                <table class="info-table">
                    $((New-HtmlTableRow -Label "Manufacturer" -Value $BIOSInfo.Manufacturer))
                    $((New-HtmlTableRow -Label "Version" -Value $BIOSInfo.Version))
                    $((New-HtmlTableRow -Label "Release Date" -Value $BIOSInfo.ReleaseDate))
                </table>
            </div>
        </div>

        <!-- Storage Card (Full Width) -->
        <div class="card card-full">
            <div class="card-header">$EmojiStorage Storage</div>
            <div class="card-body">
                $storageCards
            </div>
        </div>

        <!-- Network Card (Full Width) -->
        <div class="card card-full">
            <div class="card-header">$EmojiNetwork Network &nbsp;|&nbsp; Internet: $internetBadge</div>
            <div class="card-body">
                $networkCards
            </div>
        </div>

        $batterySection

        <!-- Security Card -->
        <div class="card">
            <div class="card-header">$EmojiSecurity Security</div>
            <div class="card-body">
                <table class="info-table">
                    $((New-HtmlTableRow -Label "Windows Defender" -Value $defenderBadge))
                    $((New-HtmlTableRow -Label "Firewall" -Value $firewallBadge))
                    $((New-HtmlTableRow -Label "Activation" -Value $activationBadge))
                </table>
            </div>
        </div>

    </div>

    <!-- ===== FOOTER ===== -->
    <div class="footer">
        <p>KBU PC Inventory Tool v1.0.0 &nbsp;|&nbsp; Karabuk University IT Department</p>
        <p>Generated on <span id="scanTimestamp">$Script:ScanDate</span> &nbsp;|&nbsp; This tool is READ-ONLY -- No system modifications were made.</p>
    </div>

    <script>
    function showToast(msg, isError) {
        var t = document.getElementById('toast');
        t.textContent = msg;
        t.className = 'toast' + (isError ? ' error' : '');
        t.classList.add('show');
        clearTimeout(t._timeout);
        t._timeout = setTimeout(function() { t.classList.remove('show'); }, 3000);
    }
    function refreshReport() {
        var btn = document.getElementById('btnRefresh');
        if (btn.classList.contains('loading')) return;
        btn.classList.add('loading');
        var xhr = new XMLHttpRequest();
        xhr.open('GET', '/scan', true);
        xhr.timeout = 120000;
        xhr.onload = function() {
            btn.classList.remove('loading');
            if (xhr.status === 200) {
                var newDoc = document.open('text/html', 'replace');
                newDoc.write(xhr.responseText);
                newDoc.close();
                showToast('Report refreshed successfully!');
            } else {
                showToast('Refresh failed (HTTP ' + xhr.status + ')', true);
            }
        };
        xhr.onerror = function() {
            btn.classList.remove('loading');
            showToast('Cannot connect to scanner service. Restart the tool.', true);
        };
        xhr.ontimeout = function() {
            btn.classList.remove('loading');
            showToast('Scan timed out. Try again.', true);
        };
        xhr.send();
    }
    </script>

</body>
</html>
"@


    return $html
}

# ============================================================================
# REGION: HTTP Server (Live Refresh Mode)
# ============================================================================

function Start-KBUHttpServer {
    param(
        $SystemInfo,
        $CPUInfo,
        $RAMInfo,
        $GPUList,
        $DiskList,
        $Motherboard,
        $BIOSInfo,
        $NetworkInfo,
        $BatteryInfo,
        $SecurityInfo,
        $InitialHtml
    )

    $port = 0
    $url = ""
    for ($p = 58080; $p -le 58089; $p++) {
        try {
            $testUrl = "http://localhost:$p/"
            $testListener = New-Object System.Net.HttpListener
            $testListener.Prefixes.Add($testUrl)
            $testListener.Start()
            $testListener.Stop()
            $port = $p
            $url = $testUrl
            break
        } catch { }
    }
    if ($port -eq 0) {
        Write-Host "  [X] Could not find an available port (58080-58089)." -ForegroundColor Red
        Write-Host "  Please close other instances and try again." -ForegroundColor Red
        return
    }
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($url)
    $listener.Start()

    Write-Host ""
    Write-Host "  +-----------------------------------------+" -ForegroundColor Green
    Write-Host "  |   $EmojiCheck LIVE SERVER STARTED               |" -ForegroundColor Green
    Write-Host "  +-----------------------------------------+" -ForegroundColor Green
    Write-Host "  URL: $url" -ForegroundColor Cyan
    Write-Host "  Use $([char]::ConvertFromUtf32(0x1F504)) Refresh button in browser to re-scan" -ForegroundColor DarkGray
    Write-Host "  Press Ctrl+C or close this window to stop" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [!] Opening browser..." -ForegroundColor Gray
    Start-Process -FilePath $url

    $serverRunning = $true
    $currentHtml = $InitialHtml

    while ($serverRunning) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            if ($request.Url.AbsolutePath -eq "/scan") {
                Write-Host "  $([char]::ConvertFromUtf32(0x1F504)) Refresh requested -- re-scanning..." -ForegroundColor Yellow

                $Script:ScanDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

                $sys   = Get-SystemInformation
                $cpu   = Get-CPUInformation
                $ram   = Get-RAMInformation
                $gpu   = Get-GPUInformation
                $disk  = Get-StorageInformation
                $mb    = Get-MotherboardInformation
                $bios  = Get-BIOSInformation
                $net   = Get-NetworkInformation
                $bat   = Get-BatteryInformation
                $sec   = Get-SecurityInformation

                $newHtml = Build-HtmlReport `
                    -SystemInfo $sys -CPUInfo $cpu -RAMInfo $ram `
                    -GPUList $gpu -DiskList $disk -Motherboard $mb `
                    -BIOSInfo $bios -NetworkInfo $net -BatteryInfo $bat `
                    -SecurityInfo $sec

                $currentHtml = $newHtml

                $buffer = [System.Text.Encoding]::UTF8.GetBytes($currentHtml)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)

                Write-Host "  $([char]0x2713) Refresh complete. Report sent to browser." -ForegroundColor Green
            }
            else {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($currentHtml)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }

            $response.Close()
        }
        catch {
            try {
                $response.Close()
            } catch { }
        }
    }

    $listener.Stop()
}

# ============================================================================
# REGION: Main Execution
# ============================================================================

function Main {
    # Clear screen for clean output
    Clear-Host

    # ASCII art header
    Write-Host @"

    ==========================================================
          ___  ___ __  __     ___  ___     ___                          
         |  / | __ |  |  |   | __|| _ \   |_ _| _ __  __ ___ __         
         | ' /| __ ||  |  |__ | __||  _/    | | | '  \/ _| \ \/         
         | . \| || ||  |  | || ||_ || |      | | | || | ( | |>  <          
         |_|\_||_||_||_ |_| \_||___||_|  _ |___||_||_|\__|_/_/\_\         
         |_   _|| || \ | || || \| || _ \ / _ \ \ / / _ \| '__|            
           | |  | ||  \| || || \   ||   /| (_) \ V /| (_) | |              
           |_|  |_||_|\__||_||_|\_||_|_\ \___/ \_/  \___/|_|              
      
           KBU PC Inventory Tool v1.0.0
           Karabuk University IT Department
      
    ==========================================================

    [!] This tool is READ-ONLY -- No system modifications are made.

"@ -ForegroundColor Cyan

    Write-Host "  " -NoNewline
    Write-Host "[!]" -ForegroundColor Gray -NoNewline
    Write-Host " This tool is READ-ONLY -- No system modifications are made." -ForegroundColor Gray
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

    # ---------- Phase 2: Generate HTML Report ----------
    Write-Host ""
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |   PHASE 2: Generating HTML Report       |" -ForegroundColor DarkCyan
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
        -SecurityInfo  $sec
    # ---------- Phase 3: Start Live Server with Refresh ----------
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan
    Write-Host "  |   PHASE 3: Live Server Mode             |" -ForegroundColor DarkCyan
    Write-Host "  +-----------------------------------------+" -ForegroundColor DarkCyan

    Write-Host "  $([char]0x2192) Building initial HTML report..." -ForegroundColor Cyan

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

    # Also save to Desktop
    try {
        $htmlReport | Out-File -FilePath $Script:ReportPath -Encoding UTF8 -Force
        Write-Host "  $([char]0x2713) Report also saved to Desktop." -ForegroundColor Green
    } catch { }

    # Launch HTTP server (blocking -- keeps running until window is closed)
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

    # ---------- Phase 4: Open in Browser ----------
    Write-Host "  [$([char]0x2192)] Opening report in default browser..." -ForegroundColor Cyan
    try {
        Start-Process -FilePath $Script:ReportPath -ErrorAction Stop
        Write-Host "  [$([char]0x2713)] Browser launched." -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Host "  [!] Could not open browser automatically." -ForegroundColor Yellow
        Write-Host "       Please open the file manually:" -ForegroundColor Yellow
        Write-Host "       $Script:ReportPath" -ForegroundColor Yellow
        Write-Host ""
    }

    # ---------- Summary Output ----------
    Write-Host "  +-----------------------------------------+" -ForegroundColor Green
    Write-Host "  |   $EmojiCheck Report Complete!               |" -ForegroundColor Green
    Write-Host "  +-----------------------------------------+" -ForegroundColor Green
    Write-Host ""

    # Display a quick summary in console
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

    # Pause
    Write-Host "  Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Entry point
Main
