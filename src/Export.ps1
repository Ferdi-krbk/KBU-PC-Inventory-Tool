<#
.SYNOPSIS
    JSON export module for KBU PC Inventory Tool.
.DESCRIPTION
    Exports structured inventory data as JSON for integration with other
    tools. Function is independently testable with explicit parameters.
#>

function Export-InventoryJson {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$InventoryData,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $jsonFilePath = Join-Path -Path $OutputPath -ChildPath "$FileName.json"

    try {
        $jsonContent = $InventoryData | ConvertTo-Json -Depth 10
        $jsonContent | Out-File -FilePath $jsonFilePath -Encoding UTF8 -Force
        Write-Host "  $([char]0x2713) JSON report saved to $jsonFilePath" -ForegroundColor Green
    }
    catch {
        Write-Host "  [$([char]0x26A0)] WARNING: Could not save JSON report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
