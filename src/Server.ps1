<#
.SYNOPSIS
    HTTP live-refresh server for KBU PC Inventory Tool.
.DESCRIPTION
    Starts a lightweight HTTP listener using System.Net.HttpListener.
    Serves the current HTML report and handles /scan endpoint for live
    re-scanning from the browser dashboard.
#>

function Start-KBUHttpServer {
    param(
        $SystemInfo, $CPUInfo, $RAMInfo, $GPUList, $DiskList,
        $Motherboard, $BIOSInfo, $NetworkInfo, $BatteryInfo, $SecurityInfo,
        $InitialHtml
    )

    $port = 0
    $url = ""
    $startPort = $Script:ServerPort
    for ($p = $startPort; $p -le ($startPort + 9); $p++) {
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
        Write-Host "  [X] Could not find an available port ($startPort-$($startPort+9))." -ForegroundColor Red
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
    if ($Script:AutoOpen) {
        Write-Host "  [!] Opening browser..." -ForegroundColor Gray
        Start-Process -FilePath $url
    }

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

                $sys  = Get-SystemInformation
                $cpu  = Get-CPUInformation
                $ram  = Get-RAMInformation
                $gpu  = Get-GPUInformation
                $disk = Get-StorageInformation
                $mb   = Get-MotherboardInformation
                $bios = Get-BIOSInformation
                $net  = Get-NetworkInformation
                $bat  = Get-BatteryInformation
                $sec  = Get-SecurityInformation

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
            try { $response.Close() } catch { }
        }
    }

    $listener.Stop()
}
