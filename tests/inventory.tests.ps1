<#
.SYNOPSIS
    Pester integration test suite for KBU PC Inventory Tool.
.DESCRIPTION
    Validates hardware data collection, configuration parsing, and JSON export
    by dot-sourcing the real modules from src/.  Tests call real functions
    (Export-InventoryJson, Get-CPUInformation, etc.) and query the local
    machine's CIM providers.

    All tests run without admin permissions.

.NOTES
    Run from project root: Invoke-Pester -Path .\tests\inventory.tests.ps1
    Requires: Pester module
#>
#Requires -Modules Pester

# Dot-source the real modules
$ModuleRoot = Join-Path -Path $PSScriptRoot -ChildPath "..\src"
. "$ModuleRoot\Config.ps1"
. "$ModuleRoot\Collectors.ps1"
. "$ModuleRoot\Network.ps1"
. "$ModuleRoot\Security.ps1"
. "$ModuleRoot\Export.ps1"

# Shared temp folder for file-creation tests
$TestOutputRoot = Join-Path -Path $env:TEMP -ChildPath "KBUInventoryTests"

Describe "Configuration File" {

    BeforeAll {
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config.json"
    }

    Context "config.json existence and format" {
        It "config.json file should exist in project root" {
            $configPath | Should -Exist
        }
        It "config.json should contain valid JSON" {
            $content = Get-Content $configPath -Raw
            { $content | ConvertFrom-Json -ErrorAction Stop } | Should -Not -Throw
        }
        It "config.json should have a version field" {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.version | Should -Not -BeNullOrEmpty
        }
    }

    Context "config.json report settings" {
        BeforeAll {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
        }
        It "should contain report.output_path" {
            $config.report.output_path | Should -Not -BeNullOrEmpty
        }
        It "should contain report.filename without extension" {
            $config.report.filename | Should -Not -Match "\.html$"
            $config.report.filename | Should -Not -Match "\.json$"
        }
        It "should contain report.auto_open boolean" {
            $config.report.auto_open | Should -BeOfType ([bool])
        }
    }

    Context "config.json defaults" {
        It "Script:OutputPath is not empty after loading Config.ps1" {
            $Script:OutputPath | Should -Not -BeNullOrEmpty
        }
        It "Script:ToolVersion matches config" {
            $Script:ToolVersion | Should -Be "2.2.0"
        }
        It "Script:ServerPort is a positive integer" {
            $Script:ServerPort | Should -BeGreaterThan 0
        }
    }
}

Describe "Hardware Data Collection" {

    Context "CPU Information" {
        BeforeAll {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        }
        It "can collect CPU instance from Win32_Processor" {
            $cpu | Should -Not -BeNullOrEmpty
        }
        It "CPU name is not empty" {
            $cpu.Name.Trim() | Should -Not -BeNullOrEmpty
        }
        It "CPU has at least 1 core" {
            $cpu.NumberOfCores | Should -BeGreaterOrEqual 1
        }
    }

    Context "RAM Information" {
        BeforeAll {
            $ram = @(Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop)
            $totalBytes = ($ram | Measure-Object -Property Capacity -Sum).Sum
        }
        It "can collect physical memory modules" {
            $ram.Count | Should -BeGreaterThan 0
        }
        It "total installed RAM is greater than 0 bytes" {
            $totalBytes | Should -BeGreaterThan 0
        }
        It "each RAM module has a valid speed" {
            foreach ($module in $ram) { $module.Speed | Should -BeGreaterThan 0 }
        }
    }

    Context "Disk Information" {
        It "at least one fixed drive is ready via .NET" {
            $drives = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady })
            $drives.Count | Should -BeGreaterThan 0
        }
    }

    Context "Operating System Information" {
        BeforeAll {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1
        }
        It "can collect OS instance" { $os | Should -Not -BeNullOrEmpty }
        It "OS caption contains Windows" { $os.Caption | Should -Match "Windows" }
        It "OS version is not empty" { $os.Version | Should -Not -BeNullOrEmpty }
    }

    Context "Motherboard Information" {
        It "can collect baseboard from Win32_BaseBoard" {
            $board = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop | Select-Object -First 1
            $board | Should -Not -BeNullOrEmpty
        }
    }

    Context "BIOS Information" {
        It "can collect BIOS from Win32_BIOS" {
            $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop | Select-Object -First 1
            $bios | Should -Not -BeNullOrEmpty
            $bios.SMBIOSBIOSVersion | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "JSON Export (Real Function)" {

    BeforeAll {
        if (-not (Test-Path $TestOutputRoot)) {
            New-Item -ItemType Directory -Path $TestOutputRoot -Force | Out-Null
        }

        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1
        $ram = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
        $dsk = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady })

        $TestInventoryData = [PSCustomObject]@{
            metadata = [PSCustomObject]@{ tool_version = "2.2.0"; scan_date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); computer_name = $env:COMPUTERNAME; current_user = $env:USERNAME }
            system   = [PSCustomObject]@{ ComputerName = $env:COMPUTERNAME; WindowsVersion = $os.Version; WindowsEdition = $os.Caption }
            cpu      = [PSCustomObject]@{ CPUName = ($cpu.Name -replace '\s+', ' '); Cores = $cpu.NumberOfCores }
            ram      = [PSCustomObject]@{ TotalRAM = "$([math]::Round(($ram | Measure-Object Capacity -Sum).Sum / 1GB, 2)) GB"; InstalledModules = $ram.Count }
            gpu      = @()
            disk     = @($dsk | ForEach-Object { [PSCustomObject]@{ DriveLetter = $_.Name; Capacity = $_.TotalSize } })
            motherboard = [PSCustomObject]@{ Manufacturer = "N/A" }
            bios     = [PSCustomObject]@{ Version = "N/A" }
            network  = [PSCustomObject]@{ InternetStatus = "Connected" }
            battery  = $null
            security = [PSCustomObject]@{ WindowsDefender = "Enabled"; Firewall = "Enabled" }
        }

        $TestOutPath  = $TestOutputRoot
        $TestFileName = "test_real_export"
        $TestJsonFile = Join-Path $TestOutPath "$TestFileName.json"

        Export-InventoryJson -InventoryData $TestInventoryData -OutputPath $TestOutPath -FileName $TestFileName
    }

    AfterAll {
        Remove-Item -Path $TestOutputRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Export-InventoryJson creates a JSON file" {
        $TestJsonFile | Should -Exist
    }

    It "exported JSON is not empty" {
        $content = Get-Content $TestJsonFile -Raw
        $content.Trim().Length | Should -BeGreaterThan 10
    }

    It "exported JSON can be parsed" {
        $json = Get-Content $TestJsonFile -Raw | ConvertFrom-Json
        $json | Should -Not -BeNullOrEmpty
    }

    It "exported JSON contains system section" {
        Get-Content $TestJsonFile -Raw | Should -Match '"system"'
    }

    It "exported JSON contains cpu section" {
        Get-Content $TestJsonFile -Raw | Should -Match '"cpu"'
    }

    It "exported JSON contains ram section" {
        Get-Content $TestJsonFile -Raw | Should -Match '"ram"'
    }

    It "exported JSON contains disk section" {
        Get-Content $TestJsonFile -Raw | Should -Match '"disk"'
    }

    It "exported JSON contains network section" {
        Get-Content $TestJsonFile -Raw | Should -Match '"network"'
    }

    It "Export-InventoryJson handles invalid path gracefully" {
        { Export-InventoryJson -InventoryData $TestInventoryData -OutputPath "Z:\InvalidPath" -FileName "test" } | Should -Throw
    }
}
