<#
.SYNOPSIS
    Pester integration test suite for KBU PC Inventory Tool
.DESCRIPTION
    Validates hardware data collection, configuration parsing, and JSON export
    using real system data. These are integration-style tests — they call actual
    CIM/WMI queries against the current machine.

    All tests are designed to run without admin permissions.

.NOTES
    Run with: Invoke-Pester -Path .\tests\inventory.tests.ps1
    Requires: Pester module (Install-Module -Name Pester -Force)
#>

#Requires -Modules Pester

# ---------------------------------------------------------------------
# Shared test setup: define temp output folder and collect real hardware
# data once at the top level so all Describe blocks can reuse it.
# ---------------------------------------------------------------------

$TestOutputRoot = Join-Path -Path $env:TEMP -ChildPath "KBUInventoryTests"

BeforeDiscovery {
    # Ensure test output folder exists (created once per suite run)
    if (-not (Test-Path $TestOutputRoot)) {
        New-Item -ItemType Directory -Path $TestOutputRoot -Force | Out-Null
    }
}

# =========================================================================
# Describe: Configuration File
# =========================================================================

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
        It "should contain report.output_path" {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.report.output_path | Should -Not -BeNullOrEmpty
        }

        It "should contain report.filename" {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.report.filename | Should -Not -BeNullOrEmpty
        }

        It "report.filename should not contain file extension" {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.report.filename | Should -Not -Match "\.html$"
            $config.report.filename | Should -Not -Match "\.json$"
        }

        It "should contain report.auto_open boolean" {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.report.auto_open | Should -BeOfType ([bool])
        }
    }

    Context "config.json server settings" {
        It "should contain server.port" {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.server.port | Should -BeGreaterThan 1024
        }

        It "should contain server.refresh_interval" {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.server.refresh_interval | Should -BeGreaterThan 0
        }
    }
}

# =========================================================================
# Describe: Hardware Data Collection
#   These tests query the LOCAL machine's CIM/WMI providers.
#   Results depend on the current hardware — a VM with 1 core, a laptop
#   with a battery, or a desktop with 32 GB RAM will all pass.
# =========================================================================

Describe "Hardware Data Collection" {

    Context "CPU Information" {
        BeforeAll {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
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

        It "CPU has at least as many logical processors as cores" {
            $cpu.NumberOfLogicalProcessors | Should -BeGreaterOrEqual $cpu.NumberOfCores
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

        It "total RAM converted to GB is at least 1 GB" {
            $totalGB = [math]::Round($totalBytes / 1GB, 0)
            $totalGB | Should -BeGreaterOrEqual 1
        }

        It "each RAM module has a valid speed" {
            foreach ($module in $ram) {
                $module.Speed | Should -BeGreaterThan 0
            }
        }
    }

    Context "Disk Information" {
        It "can collect disk drives via CIM" {
            $disks = @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop)
            $disks.Count | Should -BeGreaterThan 0
        }

        It "at least one fixed drive is ready via .NET" {
            $drives = @([System.IO.DriveInfo]::GetDrives() |
                Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady })
            $drives.Count | Should -BeGreaterThan 0
        }

        It "system drive (C:) has free space greater than 0" {
            $drive = [System.IO.DriveInfo]::GetDrives() |
                Where-Object { $_.Name -eq "C:\" -and $_.IsReady } |
                Select-Object -First 1
            $drive | Should -Not -BeNullOrEmpty
            $drive.AvailableFreeSpace | Should -BeGreaterThan 0
        }
    }

    Context "Operating System Information" {
        BeforeAll {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -First 1
        }

        It "can collect OS instance from Win32_OperatingSystem" {
            $os | Should -Not -BeNullOrEmpty
        }

        It "OS caption contains Windows" {
            $os.Caption | Should -Match "Windows"
        }

        It "OS version is not empty" {
            $os.Version | Should -Not -BeNullOrEmpty
        }

        It "OS architecture is either 32-bit or 64-bit" {
            $os.OSArchitecture | Should -Match "64-bit|32-bit"
        }
    }

    Context "Motherboard Information" {
        BeforeAll {
            $board = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop |
                Select-Object -First 1
        }

        It "can collect baseboard from Win32_BaseBoard" {
            $board | Should -Not -BeNullOrEmpty
        }

        It "motherboard manufacturer is not empty" {
            $board.Manufacturer | Should -Not -BeNullOrEmpty
        }
    }

    Context "BIOS Information" {
        BeforeAll {
            $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop |
                Select-Object -First 1
        }

        It "can collect BIOS from Win32_BIOS" {
            $bios | Should -Not -BeNullOrEmpty
        }

        It "SMBIOS version is not empty" {
            $bios.SMBIOSBIOSVersion | Should -Not -BeNullOrEmpty
        }
    }

    Context "Network Information" {
        It "can collect active network adapters" {
            $adapters = Get-CimInstance -ClassName Win32_NetworkAdapter `
                -Filter "NetEnabled=True AND PhysicalAdapter=True" -ErrorAction Stop
            $adapters | Should -Not -BeNullOrEmpty
        }
    }
}

# =========================================================================
# Describe: JSON Export (Integration Tests)
#   These tests build a real inventory data object using live CIM queries,
#   export it to a temporary file, and validate the output.
#   The temp folder is cleaned up after each Context.
# =========================================================================

Describe "JSON Export Integration" {

    BeforeAll {
        $testFolder = Join-Path $env:TEMP "KBUInventoryTests_JSON"
        if (-not (Test-Path $testFolder)) {
            New-Item -ItemType Directory -Path $testFolder -Force | Out-Null
        }

        # Collect live system data for the inventory object
        $os       = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1
        $cpu      = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $ramMods  = @(Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop)
        $gpuList  = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop)
        $diskList = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady })
        $board    = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop | Select-Object -First 1
        $bios     = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop | Select-Object -First 1

        # Build InventoryData in the same structure as the main script
        $TestInventoryData = [PSCustomObject]@{
            metadata = [PSCustomObject]@{
                tool_version  = "2.1.0"
                scan_date     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                computer_name = $env:COMPUTERNAME
                current_user  = $env:USERNAME
            }
            system = [PSCustomObject]@{
                ComputerName   = $env:COMPUTERNAME
                LoggedInUser   = $env:USERNAME
                WindowsEdition = $os.Caption
                WindowsVersion = $os.Version
                BuildNumber    = $os.BuildNumber
                Architecture   = $os.OSArchitecture
            }
            cpu = [PSCustomObject]@{
                CPUName       = ($cpu.Name -replace '\s+', ' ')
                Manufacturer  = $cpu.Manufacturer
                Cores         = $cpu.NumberOfCores
                Threads       = $cpu.NumberOfLogicalProcessors
                MaxClockSpeed = "$($cpu.MaxClockSpeed) MHz"
            }
            ram = [PSCustomObject]@{
                TotalRAM         = "$([math]::Round(($ramMods | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)) GB"
                InstalledModules = $ramMods.Count
                Modules          = @($ramMods | ForEach-Object {
                    [PSCustomObject]@{ Capacity = $_.Capacity; Speed = $_.Speed; Manufacturer = $_.Manufacturer }
                })
            }
            gpu = @($gpuList | ForEach-Object {
                [PSCustomObject]@{ GPUName = $_.Name; DriverVersion = $_.DriverVersion }
            })
            disk = @($diskList | ForEach-Object {
                [PSCustomObject]@{
                    DriveLetter  = $_.Name
                    Capacity     = $_.TotalSize
                    FreeSpace    = $_.AvailableFreeSpace
                }
            })
            motherboard = [PSCustomObject]@{
                Manufacturer = $board.Manufacturer
                Model        = $board.Product
            }
            bios = [PSCustomObject]@{
                Manufacturer = $bios.Manufacturer
                Version      = $bios.SMBIOSBIOSVersion
            }
            network = [PSCustomObject]@{
                InternetStatus = "Connected"
            }
            battery  = $null
            security = [PSCustomObject]@{
                WindowsDefender = "Enabled"
                Firewall        = "Enabled"
            }
        }
    }

    AfterAll {
        # Cleanup test folder
        if (Test-Path $testFolder) {
            Remove-Item -Path $testFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "File creation" {
        BeforeAll {
            $testFile = Join-Path $testFolder "test_inventory.json"
            $TestInventoryData | ConvertTo-Json -Depth 10 |
                Out-File -FilePath $testFile -Encoding UTF8 -Force
        }

        It "creates a JSON file at the specified path" {
            $testFile | Should -Exist
        }

        It "JSON file is not empty" {
            $content = Get-Content $testFile -Raw
            $content | Should -Not -BeNullOrEmpty
            $content.Trim().Length | Should -BeGreaterThan 10
        }

        It "exported JSON can be parsed back into an object" {
            $content = Get-Content $testFile -Raw
            $parsed = $content | ConvertFrom-Json
            $parsed | Should -Not -BeNullOrEmpty
        }
    }

    Context "Content validation" {
        BeforeAll {
            $testFile = Join-Path $testFolder "test_validation.json"
            $TestInventoryData | ConvertTo-Json -Depth 10 |
                Out-File -FilePath $testFile -Encoding UTF8 -Force
            $jsonContent = Get-Content $testFile -Raw
        }

        $expectedSections = @(
            "metadata", "system", "cpu", "ram", "gpu", "disk",
            "motherboard", "bios", "network", "security"
        )

        foreach ($section in $expectedSections) {
            It "exported JSON contains '$section' section" -ForEach $section {
                $jsonContent | Should -Match "`"$section`""
            }
        }

        It "system section contains ComputerName" {
            $jsonContent | Should -Match '"ComputerName"'
        }

        It "cpu section contains CPUName" {
            $jsonContent | Should -Match '"CPUName"'
        }

        It "ram section contains TotalRAM" {
            $jsonContent | Should -Match '"TotalRAM"'
        }

        It "disk section contains DriveLetter" {
            $jsonContent | Should -Match '"DriveLetter"'
        }

        It "metadata section contains computer_name" {
            $jsonContent | Should -Match '"computer_name"'
        }

        It "battery section serializes null gracefully" {
            $jsonContent | Should -Match '"battery"'
        }
    }

    Context "Error handling" {
        It "handles invalid output path gracefully" {
            $invalidPath = "Z:\NonExistentDrive\Folder"
            $jsonOut = $TestInventoryData | ConvertTo-Json -Depth 10
            { $jsonOut | Out-File -FilePath (Join-Path $invalidPath "test.json") -Encoding UTF8 -ErrorAction Stop } |
                Should -Throw
        }

        It "handles null InventoryData gracefully" {
            { $null | ConvertTo-Json -Depth 10 } | Should -Throw
        }

        It "handles deeply nested objects within Depth 10" {
            $deep = [PSCustomObject]@{}
            $current = $deep
            1..8 | ForEach-Object {
                $propName = "level$_"
                $current | Add-Member -MemberType NoteProperty -Name $propName -Value ([PSCustomObject]@{})
                $current = $current.$propName
            }
            $current | Add-Member -MemberType NoteProperty -Name "value" -Value "deep data"

            $deepJson = $deep | ConvertTo-Json -Depth 10
            $deepJson | Should -Match "deep data"
        }
    }
}
