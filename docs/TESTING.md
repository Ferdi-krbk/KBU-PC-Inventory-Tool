# KBU PC Inventory Tool — Testing Strategy

## Overview

The test suite in `tests/inventory.tests.ps1` uses **Pester**, the standard
PowerShell testing framework. Tests are integration-style — they query the
actual Windows CIM/WMI providers on the machine running them.

## What Is Tested

| Category            | Description                                                  |
|---------------------|--------------------------------------------------------------|
| Configuration       | `config.json` exists, is valid JSON, contains required fields |
| Hardware (CPU)      | Processor instance, name, cores, threads                     |
| Hardware (RAM)      | Total capacity, module count, individual module speed        |
| Hardware (Disk)     | CIM drives, .NET DriveInfo, C: drive free space              |
| Operating System    | OS instance, caption, version, architecture                  |
| Motherboard         | BaseBoard instance, manufacturer                             |
| BIOS                | BIOS instance, SMBIOS version                                |
| JSON Export         | File creation, parseability, section keys, null handling     |
| JSON Error Handling | Invalid paths, null input, deep nesting                      |

## Which Tests Use Live System Data

All hardware tests query the local machine's CIM providers:

- `Get-CimInstance -ClassName Win32_Processor` — real CPU data
- `Get-CimInstance -ClassName Win32_PhysicalMemory` — real RAM data
- `Get-CimInstance -ClassName Win32_DiskDrive` — real disk data
- `[System.IO.DriveInfo]::GetDrives()` — real drive info (no admin)
- `Get-CimInstance -ClassName Win32_OperatingSystem` — real OS data
- `Get-CimInstance -ClassName Win32_BaseBoard` — real motherboard data
- `Get-CimInstance -ClassName Win32_BIOS` — real BIOS data
- `Get-CimInstance -ClassName Win32_NetworkAdapter` — real network adapters

These tests pass on any Windows 10/11 machine regardless of hardware specs.
A VM with 1 core and 2 GB RAM passes just like a workstation with 16 cores
and 128 GB RAM.

The JSON export tests also use live system data — `BeforeAll` collects real
CIM information, builds an `InventoryData` object (matching the structure
used by `src/KBU_PC_Inventory.ps1`), exports it to a temp file, and verifies
the output.

## Which Tests Use Temporary Files

All JSON export tests write to `$env:TEMP\KBUInventoryTests_JSON\`.

- `test_inventory.json` — file creation and parseability
- `test_validation.json` — content section validation

The temp folder is created in `BeforeAll` and deleted in `AfterAll`. No test
files are written to the Desktop or the project directory.

## Why Some Hardware Tests Depend on the Current Machine

The tool's purpose is to inventory a real machine. Mocking CIM calls would
defeat the purpose — the tests exist to catch regressions in the data
collection pipeline.

For example, if a Windows update changes `Win32_Processor` behavior (different
property names, removed CIM class), the test fails immediately instead of
producing a broken report in production.

## Running the Tests

```powershell
# Install Pester (one time)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run from the project root
Invoke-Pester -Path .\tests\inventory.tests.ps1

# Run with verbose output
Invoke-Pester -Path .\tests\inventory.tests.ps1 -Output Detailed
```

## Test File Structure

```
tests/
└── inventory.tests.ps1
    ├── Describe "Configuration File"
    │   ├── config.json existence and format
    │   ├── config.json report settings
    │   └── config.json server settings
    ├── Describe "Hardware Data Collection"
    │   ├── CPU Information
    │   ├── RAM Information
    │   ├── Disk Information
    │   ├── Operating System Information
    │   ├── Motherboard Information
    │   ├── BIOS Information
    │   └── Network Information
    └── Describe "JSON Export Integration"
        ├── File creation
        ├── Content validation
        └── Error handling
```

## Design Principles

- **No admin required** — All tests use CIM and .NET APIs available without elevation
- **No mock for the function under test** — JSON export tests verify real serialization
- **Temp output only** — Test files go to `$env:TEMP`, never to Desktop
- **Cleanup** — `AfterAll` removes temp folders
- **Real data** — Hardware tests depend on the current machine for coverage of real-world data shapes
