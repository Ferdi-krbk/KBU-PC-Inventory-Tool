<#
.SYNOPSIS
    Configuration loader for KBU PC Inventory Tool.
.DESCRIPTION
    Defines emoji/Unicode constants, loads config.json, resolves all runtime
    settings (output path, filename, ports, version), and provides safe
    defaults when config is missing or invalid.
#>

# ============================================================================
# Unicode Character Definitions
# ============================================================================

$EmojiCheck     = [char]0x2705
$EmojiWarn      = [char]0x26A0 + [char]0xFE0F
$EmojiSystem    = [char]::ConvertFromUtf32(0x1F5A5) + [char]0xFE0F
$EmojiCpu       = [char]0x2699 + [char]0xFE0F
$EmojiRam       = [char]::ConvertFromUtf32(0x1F9E0)
$EmojiGpu       = [char]::ConvertFromUtf32(0x1F3AE)
$EmojiStorage   = [char]::ConvertFromUtf32(0x1F4BE)
$EmojiMobo      = [char]::ConvertFromUtf32(0x1F527)
$EmojiBios      = [char]::ConvertFromUtf32(0x1F50C)
$EmojiNetwork   = [char]::ConvertFromUtf32(0x1F310)
$EmojiBattery   = [char]::ConvertFromUtf32(0x1F50B)
$EmojiSecurity  = [char]::ConvertFromUtf32(0x1F6E1) + [char]0xFE0F
$EmojiClipboard = [char]::ConvertFromUtf32(0x1F4CB)
$EmojiSummary   = [char]::ConvertFromUtf32(0x1F4CA)
$EmojiWindows   = [char]::ConvertFromUtf32(0x1FA9F)
$EmojiMicroscope = [char]::ConvertFromUtf32(0x1F52C)
$EmojiPlug      = [char]::ConvertFromUtf32(0x1F50C)

# ============================================================================
# Config Loading
# ============================================================================

$Script:ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config.json"
$Script:Config = $null

if (Test-Path $Script:ConfigPath) {
    try {
        $Script:Config = Get-Content $Script:ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        Write-Host "  [$([char]0x2713)] Configuration loaded from config.json" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "  [$([char]0x26A0)] WARNING: Could not parse config.json, using default values." -ForegroundColor Yellow
        $Script:Config = $null
    }
}
else {
    Write-Host "  [$([char]0x26A0)] WARNING: config.json not found at $Script:ConfigPath, using default values." -ForegroundColor Yellow
}

# ============================================================================
# Defaults & Resolved Values
# ============================================================================

$Script:DefaultOutputPath = "C:\Users\Public\Desktop"
$Script:DefaultFilename  = "KBU_Inventory_Report"
$Script:DefaultPort      = 58080

$Script:OutputPath = if ($Script:Config -and $Script:Config.report -and $Script:Config.report.output_path) {
    $Script:Config.report.output_path
} else {
    $Script:DefaultOutputPath
}
$Script:ReportFilename = if ($Script:Config -and $Script:Config.report -and $Script:Config.report.filename) {
    $Script:Config.report.filename
} else {
    $Script:DefaultFilename
}
$Script:AutoOpen = if ($Script:Config -and $Script:Config.report -and ($null -ne $Script:Config.report.auto_open)) {
    $Script:Config.report.auto_open
} else {
    $true
}
$Script:ServerPort = if ($Script:Config -and $Script:Config.server -and $Script:Config.server.port) {
    $Script:Config.server.port
} else {
    $Script:DefaultPort
}
$Script:ToolVersion = if ($Script:Config -and $Script:Config.version) {
    $Script:Config.version
} else {
    "2.2.0"
}

if (-not (Test-Path $Script:OutputPath)) {
    try {
        New-Item -ItemType Directory -Path $Script:OutputPath -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "  [$([char]0x26A0)] WARNING: Could not create output path $Script:OutputPath, falling back to Desktop." -ForegroundColor Yellow
        $Script:OutputPath = if ([Environment]::GetFolderPath("Desktop")) {
            [Environment]::GetFolderPath("Desktop")
        } else {
            Join-Path -Path $env:USERPROFILE -ChildPath "Desktop"
        }
    }
}

$Script:ReportPath     = Join-Path -Path $Script:OutputPath -ChildPath "$($Script:ReportFilename).html"
$Script:JsonReportPath = Join-Path -Path $Script:OutputPath -ChildPath "$($Script:ReportFilename).json"
$Script:CurrentUser    = [System.Environment]::UserName
$Script:ComputerName   = [System.Environment]::MachineName
$Script:ScanDate       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "  [$([char]0x2192)] Output path: $($Script:OutputPath)" -ForegroundColor DarkGray
