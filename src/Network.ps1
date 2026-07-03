<#
.SYNOPSIS
    Network information collector for KBU PC Inventory Tool.
.DESCRIPTION
    Collects active network adapters, IP configuration, and internet
    connectivity status using CIM/WMI.
#>

function Get-NetworkInformation {
    Write-Host "  [$([char]0x2192)] Collecting Network Information..." -ForegroundColor Cyan

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

    $internetStatus = Invoke-SafeQuery -Label "Internet" -ScriptBlock {
        $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ping) { "Connected" } else { "Disconnected" }
    }

    return [PSCustomObject]@{
        Adapters       = $netList
        InternetStatus = $internetStatus
    }
}
