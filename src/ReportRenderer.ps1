<#
.SYNOPSIS
    HTML report renderer for KBU PC Inventory Tool.
.DESCRIPTION
    Generates a self-contained HTML5 dashboard from collected inventory data.
    Contains Build-HtmlReport and its helper functions (New-HtmlTableRow,
    New-HtmlBadge). Depends on Config.ps1 for emoji/$Script: variables and
    Collectors.ps1 for Get-StatusBadgeClass/Get-SectionIcon.
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

function New-HtmlBadge {
    param([string]$Text, [string]$Status)
    $cssClass = Get-StatusBadgeClass -Status $Status
    return "<span class='badge $cssClass'>$Text</span>"
}

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

    $localWarnings = 0
    $localErrors   = 0

    foreach ($disk in @($DiskList)) {
        if ($disk.UsageStatus -eq "Error") { $localErrors++ }
        elseif ($disk.UsageStatus -eq "Warning") { $localWarnings++ }
    }

    if ($SecurityInfo.Activation -ne "Licensed" -and $SecurityInfo.Activation -ne "Not Available") { $localWarnings++ }

    if ($BatteryInfo) {
        if ($BatteryInfo.BatteryStatus -match "Critical|Low") { $localErrors++ }
        elseif ($BatteryInfo.BatteryStatus -eq "Discharging") { $localWarnings++ }
    }

    if ($NetworkInfo.InternetStatus -eq "Disconnected") { $localWarnings++ }

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

    $ramModulesRows = ""
    if ($RAMInfo.Modules.Count -gt 0) {
        foreach ($mod in $RAMInfo.Modules) {
            $ramModulesRows += New-HtmlTableRow -Label "Module" -Value "$($mod.Manufacturer) -- $($mod.PartNumber) | $($mod.Capacity) @ $($mod.Speed)"
        }
    } else {
        $ramModulesRows = New-HtmlTableRow -Label "Modules" -Value "Not Available"
    }

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

    $defenderBadge  = New-HtmlBadge -Text $SecurityInfo.WindowsDefender -Status $SecurityInfo.WindowsDefender
    $firewallBadge  = New-HtmlBadge -Text $SecurityInfo.Firewall -Status $SecurityInfo.Firewall
    $activationBadge = New-HtmlBadge -Text $SecurityInfo.Activation -Status $SecurityInfo.Activation

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

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>KBU PC Inventory Report -- $Script:ComputerName</title>
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0f1923; color: #e0e6ed; min-height: 100vh; line-height: 1.6; }
        .hero { background: linear-gradient(135deg, #0a1628 0%, #13203d 50%, #1a2d4a 100%); border-bottom: 3px solid #00b4d8; padding: 32px 24px; text-align: center; }
        .hero h1 { font-size: 2.2rem; font-weight: 700; color: #ffffff; letter-spacing: -0.5px; margin-bottom: 4px; }
        .hero .subtitle { font-size: 0.95rem; color: #90e0ef; letter-spacing: 2px; text-transform: uppercase; }
        .hero .scan-info { margin-top: 10px; font-size: 0.85rem; color: #9aa4b2; }
        .container { max-width: 1320px; margin: 0 auto; padding: 28px 20px; display: grid; grid-template-columns: repeat(auto-fit, minmax(420px, 1fr)); gap: 22px; }
        .summary-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 16px; margin-bottom: 8px; }
        .summary-card { background: linear-gradient(145deg, #1a2d3d, #142130); border: 1px solid #2a3f55; border-radius: 12px; padding: 20px 16px; text-align: center; transition: transform 0.2s, box-shadow 0.2s; }
        .summary-card:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0, 180, 216, 0.12); }
        .summary-card .summary-icon { font-size: 2rem; margin-bottom: 8px; }
        .summary-card .summary-label { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1.5px; color: #7c8da0; margin-bottom: 6px; }
        .summary-card .summary-value { font-size: 1.05rem; font-weight: 600; color: #e0e6ed; word-break: break-word; }
        .card { background: linear-gradient(145deg, #1a2d3d, #142130); border: 1px solid #2a3f55; border-radius: 12px; overflow: hidden; display: flex; flex-direction: column; }
        .card-header { background: rgba(0, 180, 216, 0.08); border-bottom: 1px solid #2a3f55; padding: 14px 20px; font-size: 1rem; font-weight: 700; color: #00b4d8; letter-spacing: 0.5px; }
        .card-body { padding: 16px 20px; flex: 1; }
        .card-full { grid-column: 1 / -1; }
        .info-table { width: 100%; border-collapse: collapse; }
        .info-table tr:not(:last-child) { border-bottom: 1px solid rgba(42, 63, 85, 0.4); }
        .info-table td { padding: 10px 4px; vertical-align: middle; }
        .info-label { font-size: 0.82rem; font-weight: 600; color: #7c8da0; text-transform: uppercase; letter-spacing: 0.8px; width: 160px; white-space: nowrap; }
        .info-value { font-size: 0.92rem; color: #d4dce6; word-break: break-word; }
        .separator td { padding: 0; border-bottom: 1px dashed #2a3f55; height: 1px; }
        .mono { font-family: 'Consolas', 'Courier New', monospace; font-size: 0.85rem; }
        .badge { display: inline-block; padding: 4px 14px; border-radius: 20px; font-size: 0.78rem; font-weight: 600; letter-spacing: 0.4px; white-space: nowrap; }
        .badge-ok { background: #064e3b; color: #6ee7b7; border: 1px solid #065f46; }
        .badge-warn { background: #5c4b00; color: #fde68a; border: 1px solid #7c5e00; }
        .badge-error { background: #5b1a1a; color: #fca5a5; border: 1px solid #7f1d1d; }
        .badge-ready { background: linear-gradient(135deg, #064e3b, #047857); color: #d1fae5; border: 2px solid #10b981; font-size: 0.95rem; padding: 8px 24px; letter-spacing: 1px; animation: pulse-glow 2s infinite; }
        @keyframes pulse-glow { 0%, 100% { box-shadow: 0 0 8px rgba(16, 185, 129, 0.3); } 50% { box-shadow: 0 0 20px rgba(16, 185, 129, 0.6); } }
        .progress-bar { background: #0f1923; border-radius: 10px; height: 10px; margin-top: 12px; overflow: hidden; }
        .progress-fill { height: 100%; border-radius: 10px; transition: width 0.5s ease; }
        .progress-ok { background: linear-gradient(90deg, #10b981, #34d399); }
        .progress-warn { background: linear-gradient(90deg, #f59e0b, #fbbf24); }
        .progress-error { background: linear-gradient(90deg, #ef4444, #f87171); }
        .progress-label { font-size: 0.75rem; color: #7c8da0; margin-top: 4px; text-align: right; }
        .storage-item { background: rgba(15, 25, 35, 0.5); border: 1px solid #2a3f55; border-radius: 8px; padding: 14px 16px; margin-bottom: 12px; }
        .storage-header { font-weight: 700; color: #e0e6ed; font-size: 0.95rem; margin-bottom: 8px; }
        .status-banner { text-align: center; padding: 20px; margin-bottom: 8px; }
        .footer { text-align: center; padding: 28px 20px; color: #4a5d70; font-size: 0.8rem; border-top: 1px solid #1a2d3d; margin-top: 20px; }
        .refresh-btn { display: inline-flex; align-items: center; gap: 8px; padding: 12px 28px; background: linear-gradient(135deg, #00b4d8, #0077b6); color: #fff; border: none; border-radius: 8px; font-size: 0.95rem; font-weight: 700; cursor: pointer; letter-spacing: 0.5px; transition: all 0.2s ease; box-shadow: 0 4px 15px rgba(0, 180, 216, 0.3); }
        .refresh-btn:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0, 180, 216, 0.5); }
        .refresh-btn:active { transform: translateY(0); }
        .refresh-btn.loading { pointer-events: none; opacity: 0.7; }
        .refresh-spinner { display: none; width: 18px; height: 18px; border: 3px solid rgba(255,255,255,0.3); border-top-color: #fff; border-radius: 50%; animation: spinner-rotate 0.7s linear infinite; }
        .refresh-btn.loading .refresh-spinner { display: inline-block; }
        .refresh-btn.loading .refresh-icon { display: none; }
        @keyframes spinner-rotate { to { transform: rotate(360deg); } }
        .toast { position: fixed; top: 20px; left: 50%; transform: translateX(-50%); background: #064e3b; color: #6ee7b7; padding: 10px 24px; border-radius: 8px; font-size: 0.9rem; font-weight: 600; z-index: 9999; opacity: 0; transition: opacity 0.3s ease; pointer-events: none; border: 1px solid #10b981; }
        .toast.show { opacity: 1; }
        .toast.error { background: #5b1a1a; color: #fca5a5; border-color: #ef4444; }
        @media (max-width: 768px) { .container { grid-template-columns: 1fr; padding: 14px 10px; gap: 14px; } .hero h1 { font-size: 1.5rem; } .summary-row { grid-template-columns: repeat(2, 1fr); } .info-label { width: 110px; font-size: 0.7rem; } .info-value { font-size: 0.8rem; } }
        @media (max-width: 480px) { .summary-row { grid-template-columns: 1fr; } .hero { padding: 20px 12px; } .hero h1 { font-size: 1.3rem; } }
        @media print { body { background: #fff; color: #111; } .card, .summary-card, .storage-item { background: #f9fafb; border: 1px solid #ccc; } .card-header { background: #e5e7eb; color: #111; } .badge { border: 1px solid #666 !important; } .refresh-btn, .toast { display: none !important; } }
    </style>
</head>
<body>
    <div class="hero">
        <h1>$EmojiMicroscope KBU PC Inventory Tool</h1>
        <div class="subtitle">System Diagnostics & Inventory Report</div>
        <div class="scan-info">
            Computer: <strong>$Script:ComputerName</strong> &nbsp;|&nbsp;
            User: <strong>$Script:CurrentUser</strong> &nbsp;|&nbsp;
            Scanned: <strong>$Script:ScanDate</strong>
        </div>
    </div>
    <div class="status-banner">$readyBadge</div>
    <div class="status-banner" style="padding-top:0;">
        <button class="refresh-btn" id="btnRefresh" onclick="refreshReport()">
            <span class="refresh-icon">$([char]::ConvertFromUtf32(0x1F504))</span>
            <span class="refresh-spinner"></span>
            Refresh Report
        </button>
    </div>
    <div class="toast" id="toast"></div>
    <div class="container" style="margin-bottom:0;">
        <div class="card card-full">
            <div class="card-header">$EmojiSummary System Summary</div>
            <div class="card-body">
                <div class="summary-row">
                    <div class="summary-card"><div class="summary-icon">$EmojiCpu</div><div class="summary-label">CPU</div><div class="summary-value">$($CPUInfo.CPUName)</div></div>
                    <div class="summary-card"><div class="summary-icon">$EmojiRam</div><div class="summary-label">Total RAM</div><div class="summary-value">$($RAMInfo.TotalRAM)</div></div>
                    <div class="summary-card"><div class="summary-icon">$EmojiGpu</div><div class="summary-label">GPU</div><div class="summary-value">$summaryGPU</div></div>
                    <div class="summary-card"><div class="summary-icon">$EmojiStorage</div><div class="summary-label">Disk</div><div class="summary-value">$(if (@($DiskList).Count -gt 0) { $d = $DiskList[0]; if ($d.MediaType -ne "Not Available") { "$($d.Capacity) ($($d.MediaType))" } else { $d.Capacity } } else { "Not Available" })</div></div>
                    <div class="summary-card"><div class="summary-icon">$EmojiWindows</div><div class="summary-label">Windows</div><div class="summary-value">$($SystemInfo.WindowsEdition)</div></div>
                    <div class="summary-card"><div class="summary-icon">$EmojiClipboard</div><div class="summary-label">Overall Status</div><div class="summary-value">$(New-HtmlBadge -Text $overallStatus.ToUpper() -Status $overallStatus)</div></div>
                </div>
            </div>
        </div>
    </div>
    <div class="container">
        <div class="card"><div class="card-header">$EmojiSystem System Information</div><div class="card-body"><table class="info-table">$(New-HtmlTableRow -Label "Computer Name" -Value $SystemInfo.ComputerName)$(New-HtmlTableRow -Label "Logged-in User" -Value $SystemInfo.LoggedInUser)$(New-HtmlTableRow -Label "Windows Edition" -Value $SystemInfo.WindowsEdition)$(New-HtmlTableRow -Label "Version" -Value $SystemInfo.WindowsVersion)$(New-HtmlTableRow -Label "Build Number" -Value $SystemInfo.BuildNumber)$(New-HtmlTableRow -Label "Architecture" -Value $SystemInfo.Architecture)$(New-HtmlTableRow -Label "Install Date" -Value $SystemInfo.InstallDate)$(New-HtmlTableRow -Label "Last Boot Time" -Value $SystemInfo.LastBootTime)$(New-HtmlTableRow -Label "Uptime" -Value $SystemInfo.Uptime)</table></div></div>
        <div class="card"><div class="card-header">$EmojiCpu CPU</div><div class="card-body"><table class="info-table">$(New-HtmlTableRow -Label "Name" -Value $CPUInfo.CPUName)$(New-HtmlTableRow -Label "Manufacturer" -Value $CPUInfo.Manufacturer)$(New-HtmlTableRow -Label "Cores" -Value $CPUInfo.Cores)$(New-HtmlTableRow -Label "Threads" -Value $CPUInfo.Threads)$(New-HtmlTableRow -Label "Max Clock Speed" -Value $CPUInfo.MaxClockSpeed)$(New-HtmlTableRow -Label "Current Usage" -Value $CPUInfo.CurrentUsage)</table></div></div>
        <div class="card"><div class="card-header">$EmojiRam RAM (Memory)</div><div class="card-body"><table class="info-table">$(New-HtmlTableRow -Label "Total RAM" -Value $RAMInfo.TotalRAM)$(New-HtmlTableRow -Label "Available RAM" -Value $RAMInfo.AvailableRAM)$(New-HtmlTableRow -Label "Used RAM" -Value $RAMInfo.UsedRAM)$(New-HtmlTableRow -Label "Installed Modules" -Value $RAMInfo.InstalledModules)$ramModulesRows</table></div></div>
        <div class="card"><div class="card-header">$EmojiGpu GPU (Graphics)</div><div class="card-body"><table class="info-table">$gpuRows</table></div></div>
        <div class="card"><div class="card-header">$EmojiMobo Motherboard</div><div class="card-body"><table class="info-table">$(New-HtmlTableRow -Label "Manufacturer" -Value $Motherboard.Manufacturer)$(New-HtmlTableRow -Label "Model" -Value $Motherboard.Model)$(New-HtmlTableRow -Label "Serial Number" -Value $Motherboard.SerialNumber)</table></div></div>
        <div class="card"><div class="card-header">$EmojiBios BIOS</div><div class="card-body"><table class="info-table">$(New-HtmlTableRow -Label "Manufacturer" -Value $BIOSInfo.Manufacturer)$(New-HtmlTableRow -Label "Version" -Value $BIOSInfo.Version)$(New-HtmlTableRow -Label "Release Date" -Value $BIOSInfo.ReleaseDate)</table></div></div>
        <div class="card card-full"><div class="card-header">$EmojiStorage Storage</div><div class="card-body">$storageCards</div></div>
        <div class="card card-full"><div class="card-header">$EmojiNetwork Network &nbsp;|&nbsp; Internet: $internetBadge</div><div class="card-body">$networkCards</div></div>
        $batterySection
        <div class="card"><div class="card-header">$EmojiSecurity Security</div><div class="card-body"><table class="info-table">$(New-HtmlTableRow -Label "Windows Defender" -Value $defenderBadge)$(New-HtmlTableRow -Label "Firewall" -Value $firewallBadge)$(New-HtmlTableRow -Label "Activation" -Value $activationBadge)</table></div></div>
    </div>
    <div class="footer">
        <p>KBU PC Inventory Tool v$Script:ToolVersion &nbsp;|&nbsp; Karabuk University IT Department</p>
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
