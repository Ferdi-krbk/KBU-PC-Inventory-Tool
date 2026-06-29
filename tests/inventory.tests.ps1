<#
.SYNOPSIS
    Pester tests for KBU PC Inventory Tool
.DESCRIPTION
    Validates that hardware data collection functions return expected results.
    These tests do not require admin permissions.
#>

Describe "Hardware Data Collection" {

    Context "CPU Information" {
        It "CPU bilgisi alinabilmeli" {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
            $cpu | Should -Not -BeNullOrEmpty
        }

        It "CPU name bos olmamali" {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
            $cpu.Name | Should -Not -BeNullOrEmpty
        }

        It "CPU core sayisi 0'dan buyuk olmali" {
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                Select-Object -First 1
            $cpu.NumberOfCores | Should -BeGreaterThan 0
        }
    }

    Context "RAM Information" {
        It "RAM bilgisi alinabilmeli" {
            $ram = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
            $ram | Should -Not -BeNullOrEmpty
        }

        It "Toplam RAM 0'dan buyuk olmali" {
            $ram = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop
            $totalRAM = ($ram | Measure-Object -Property Capacity -Sum).Sum
            $totalRAM | Should -BeGreaterThan 0
        }

        It "RAM hizi gecerli bir deger olmali" {
            $ram = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop |
                Select-Object -First 1
            $ram.Speed | Should -BeGreaterThan 0
        }
    }

    Context "Disk Information" {
        It "Disk bilgisi alinabilmeli" {
            $disk = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop
            $disk | Should -Not -BeNullOrEmpty
        }

        It "En az bir sabit disk bulunmali" {
            $drives = [System.IO.DriveInfo]::GetDrives() |
                Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }
            $drives.Count | Should -BeGreaterThan 0
        }
    }

    Context "OS Information" {
        It "OS bilgisi alinabilmeli" {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -First 1
            $os | Should -Not -BeNullOrEmpty
        }

        It "OS adi bos olmamali" {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -First 1
            $os.Caption | Should -Not -BeNullOrEmpty
        }

        It "OS versiyonu bos olmamali" {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -First 1
            $os.Version | Should -Not -BeNullOrEmpty
        }
    }

    Context "Motherboard Information" {
        It "Anakart bilgisi alinabilmeli" {
            $board = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop |
                Select-Object -First 1
            $board | Should -Not -BeNullOrEmpty
        }
    }

    Context "BIOS Information" {
        It "BIOS bilgisi alinabilmeli" {
            $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop |
                Select-Object -First 1
            $bios | Should -Not -BeNullOrEmpty
        }

        It "BIOS versiyonu bos olmamali" {
            $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop |
                Select-Object -First 1
            $bios.SMBIOSBIOSVersion | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Configuration" {

    Context "config.json parsing" {
        It "config.json dosyasi okunabilir olmali" {
            $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config.json"
            Test-Path $configPath | Should -Be $true
        }

        It "config.json gecerli JSON formatinda olmali" {
            $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config.json"
            $content = Get-Content $configPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It "config.json version alani olmali" {
            $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config.json"
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.version | Should -Not -BeNullOrEmpty
        }

        It "config.json report yapilandirmasi olmali" {
            $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config.json"
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.report | Should -Not -BeNullOrEmpty
        }

        It "config.json server yapilandirmasi olmali" {
            $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\config.json"
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $config.server | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "JSON Export Structure" {

    Context "Export format validation" {
        It "JSON ciktisi gerekli anahtarlari icermeli" {
            $sampleData = [PSCustomObject]@{
                system = [PSCustomObject]@{ computer_name = "TEST" }
                cpu    = [PSCustomObject]@{ name = "Test CPU" }
                ram    = [PSCustomObject]@{ total = "16 GB" }
                gpu    = @([PSCustomObject]@{ name = "Test GPU" })
                disk   = @([PSCustomObject]@{ drive = "C:" })
                motherboard = [PSCustomObject]@{ model = "Test Board" }
                bios   = [PSCustomObject]@{ version = "1.0" }
                network = [PSCustomObject]@{ status = "Connected" }
                battery = $null
                security = [PSCustomObject]@{ defender = "Enabled" }
            }
            $json = $sampleData | ConvertTo-Json -Depth 10
            $json | Should -Not -BeNullOrEmpty

            $expectedKeys = @("system", "cpu", "ram", "gpu", "disk", "motherboard", "bios", "network", "security")
            foreach ($key in $expectedKeys) {
                $json | Should -Match $key
            }
        }

        It "ConvertTo-Json -Depth 10 basarili olmali" {
            $complexData = [PSCustomObject]@{
                level1 = [PSCustomObject]@{
                    level2 = [PSCustomObject]@{
                        level3 = [PSCustomObject]@{
                            level4 = "deep value"
                        }
                    }
                }
            }
            $json = $complexData | ConvertTo-Json -Depth 10
            $json | Should -Not -BeNullOrEmpty
            $json | Should -Match "deep value"
        }
    }
}
