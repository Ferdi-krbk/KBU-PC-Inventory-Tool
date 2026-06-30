<#
.SYNOPSIS
    Pester test suite for KBU PC Inventory Tool
.DESCRIPTION
    Validates hardware data collection, configuration parsing, and JSON export
    structure. All tests are designed to run without admin permissions.
.NOTES
    Run with: Invoke-Pester -Path .\tests\inventory.tests.ps1
    Requires: Pester module (Install-Module -Name Pester -Force)
#>

#Requires -Modules Pester

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

Describe "Hardware Data Collection" {

    Context "CPU Information" {
        It "can collect CPU instance from Win32_Processor" {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
            $cpu | Should -Not -BeNullOrEmpty
        }

        It "CPU name is not empty" {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
            $cpu.Name.Trim() | Should -Not -BeNullOrEmpty
        }

        It "CPU has at least 1 core" {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
            $cpu.NumberOfCores | Should -BeGreaterOrEqual 1
        }

        It "CPU has at least as many logical processors as cores" {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
            $cpu.NumberOfLogicalProcessors | Should -BeGreaterOrEqual $cpu.NumberOfCores
        }
    }

    Context "RAM Information" {
        It "can collect physical memory modules" {
            $ram = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
            @($ram).Count | Should -BeGreaterThan 0
        }

        It "total installed RAM is greater than 0 bytes" {
            $ram = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
            $totalBytes = ($ram | Measure-Object -Property Capacity -Sum).Sum
            $totalBytes | Should -BeGreaterThan 0
        }

        It "total RAM converted to GB is at least 1 GB" {
            $ram = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
            $totalBytes = ($ram | Measure-Object -Property Capacity -Sum).Sum
            $totalGB = [math]::Round($totalBytes / 1GB, 0)
            $totalGB | Should -BeGreaterOrEqual 1
        }

        It "each RAM module has a valid speed" {
            $ram = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
            foreach ($module in @($ram)) {
                $module.Speed | Should -BeGreaterThan 0
            }
        }
    }

    Context "Disk Information" {
        It "can collect disk drives via CIM" {
            $disks = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop
            @($disks).Count | Should -BeGreaterThan 0
        }

        It "at least one fixed drive is ready via .NET" {
            $drives = [System.IO.DriveInfo]::GetDrives() |
                Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }
            @($drives).Count | Should -BeGreaterThan 0
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
        It "can collect OS instance from Win32_OperatingSystem" {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -First 1
            $os | Should -Not -BeNullOrEmpty
        }

        It "OS caption contains Windows" {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -First 1
            $os.Caption | Should -Match "Windows"
        }

        It "OS version is not empty" {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -First 1
            $os.Version | Should -Not -BeNullOrEmpty
        }

        It "OS architecture is either 32-bit or 64-bit" {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -First 1
            $os.OSArchitecture | Should -Match "64-bit|32-bit"
        }
    }

    Context "Motherboard Information" {
        It "can collect baseboard from Win32_BaseBoard" {
            $board = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop |
                Select-Object -First 1
            $board | Should -Not -BeNullOrEmpty
        }

        It "motherboard manufacturer is not empty" {
            $board = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop |
                Select-Object -First 1
            $board.Manufacturer | Should -Not -BeNullOrEmpty
        }
    }

    Context "BIOS Information" {
        It "can collect BIOS from Win32_BIOS" {
            $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop |
                Select-Object -First 1
            $bios | Should -Not -BeNullOrEmpty
        }

        It "SMBIOS version is not empty" {
            $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop |
                Select-Object -First 1
            $bios.SMBIOSBIOSVersion | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "JSON Export Structure" {

    Context "Export object validation" {
        BeforeAll {
            $sampleData = [PSCustomObject]@{
                metadata = [PSCustomObject]@{
                    tool_version  = "2.1.0"
                    scan_date     = "2026-07-01 09:00:00"
                    computer_name = "TEST-PC"
                    current_user  = "testuser"
                }
                system   = [PSCustomObject]@{ ComputerName = "TEST-PC"; WindowsVersion = "10.0" }
                cpu      = [PSCustomObject]@{ CPUName = "Intel Core i7"; Cores = 8 }
                ram      = [PSCustomObject]@{ TotalRAM = "16 GB"; InstalledModules = 2 }
                gpu      = @([PSCustomObject]@{ GPUName = "NVIDIA RTX 3060"; VRAM = "12 GB" })
                disk     = @([PSCustomObject]@{ DriveLetter = "C:\\"; Capacity = "512 GB" })
                motherboard = [PSCustomObject]@{ Manufacturer = "ASUS"; Model = "Z690" }
                bios     = [PSCustomObject]@{ Version = "1.0"; Manufacturer = "AMI" }
                network  = [PSCustomObject]@{ InternetStatus = "Connected" }
                battery  = $null
                security = [PSCustomObject]@{ WindowsDefender = "Enabled"; Firewall = "Enabled" }
            }
            $json = $sampleData | ConvertTo-Json -Depth 10
        }

        It "JSON output is not empty" {
            $json | Should -Not -BeNullOrEmpty
        }

        $expectedSections = @(
            "metadata", "system", "cpu", "ram", "gpu", "disk",
            "motherboard", "bios", "network", "security"
        )

        foreach ($section in $expectedSections) {
            It "JSON should contain '$section' section" {
                $json | Should -Match "`"$section`""
            }
        }

        It "metadata section should contain tool_version" {
            $json | Should -Match '"tool_version"'
        }

        It "battery section should serialize null correctly" {
            $json | Should -Match '"battery"'
        }
    }

    Context "ConvertTo-Json depth handling" {
        It "nested objects up to depth 10 should serialize without data loss" {
            $deep = [PSCustomObject]@{}
            $current = $deep
            for ($i = 1; $i -le 8; $i++) {
                $propName = "level$i"
                $current | Add-Member -MemberType NoteProperty -Name $propName -Value ([PSCustomObject]@{})
                $current = $current.$propName
            }
            $current | Add-Member -MemberType NoteProperty -Name "value" -Value "deep data"

            $deepJson = $deep | ConvertTo-Json -Depth 10
            $deepJson | Should -Match "deep data"
        }
    }
}
