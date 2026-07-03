<#
.SYNOPSIS
    Hardware data collectors for KBU PC Inventory Tool.
.DESCRIPTION
    Contains shared helper functions (Invoke-SafeQuery, Format-FileSize, etc.)
    and all hardware/OS data collection functions (CPU, RAM, GPU, Disk,
    Motherboard, BIOS, Battery).
#>

# ============================================================================
# Helper Functions
# ============================================================================

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

function Format-FileSize {
    param([double]$Bytes)
    if ($Bytes -lt 0) { return "Not Available" }
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "{0:N0} Bytes" -f $Bytes
}

function Get-StatusBadgeClass {
    param([string]$Status)
    switch -Regex ($Status.ToLower()) {
        'ok|healthy|enabled|ready|running|online|charged|active|licensed' { return 'badge-ok' }
        'warning|caution|partial|degraded|discharging|not available'    { return 'badge-warn' }
        'error|failed|disabled|stopped|offline|unhealthy|critical'      { return 'badge-error' }
        default                                                           { return 'badge-warn' }
    }
}

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
# Data Collection Functions
# ============================================================================

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

function Get-StorageInformation {
    Write-Host "  [$([char]0x2192)] Collecting Storage Information..." -ForegroundColor Cyan

    $diskList = @()
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
