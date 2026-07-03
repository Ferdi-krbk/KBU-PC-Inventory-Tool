<#
.SYNOPSIS
    Security information collector for KBU PC Inventory Tool.
.DESCRIPTION
    Collects Windows Defender status, Firewall profile status, and
    Windows activation state.
#>

function Get-SecurityInformation {
    Write-Host "  [$([char]0x2192)] Collecting Security Information..." -ForegroundColor Cyan

    $defenderStatus = Invoke-SafeQuery -Label "Defender" -ScriptBlock {
        try {
            $status = Get-MpComputerStatus -ErrorAction Stop
            if ($status.AntivirusEnabled) { "Enabled" } else { "Disabled" }
        }
        catch {
            "Not Available"
        }
    }

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
