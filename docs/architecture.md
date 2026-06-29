# KBU PC Inventory Tool -- Architecture

## Project Purpose

The KBU PC Inventory Tool is a read-only PowerShell-based IT inventory application that
collects detailed system information from Windows 10/11 workstations and generates
a responsive HTML dashboard report and structured JSON export.

## Architecture Overview

```
+-------------------+
|  config.json      |  <-- User-editable configuration
+--------+----------+
         |
         v
+--------+----------+
| Inventory         |  <-- Hardware/OS data collection (CIM/WMI + .NET)
| Collector         |
+--------+----------+
         |
         v
+--------+----------+
| Data              |  <-- Safe query wrappers, date formatting, file size formatting
| Processor         |
+--------+----------+
         |
    +----+----+
    |         |
    v         v
+---+---+ +---+---+
| HTML  | | JSON  |  <-- Dual-format output
| Render| |Export |
+---+---+ +---+---+
    |
    v
+---+--------------+
| HTTP Server       |  <-- Live refresh via browser
| (Live Refresh)    |
+-------------------+
```

## Layers

### 1. Configuration Layer (`config.json`)

- **Path:** `<project-root>/config.json`
- **Fallback:** Safe default values if file is missing or invalid
- **Settings:** output path, report filename, auto-open browser, server port

### 2. Data Collection Layer

Powershell functions that read system information:

| Function                    | Data Source              | Information Collected            |
|-----------------------------|--------------------------|----------------------------------|
| `Get-SystemInformation`     | `Win32_OperatingSystem`  | OS edition, version, build, arch |
| `Get-CPUInformation`        | `Win32_Processor`        | CPU name, cores, threads, speed  |
| `Get-RAMInformation`        | `Win32_PhysicalMemory`   | Total/available/used RAM, modules |
| `Get-GPUInformation`        | `Win32_VideoController`  | GPU name, VRAM, driver version   |
| `Get-StorageInformation`    | `.NET DriveInfo`         | Drive letters, capacity, usage % |
| `Get-MotherboardInformation`| `Win32_BaseBoard`        | Manufacturer, model, serial      |
| `Get-BIOSInformation`       | `Win32_BIOS`             | Manufacturer, version, date      |
| `Get-NetworkInformation`    | `Win32_NetworkAdapter`   | Adapters, IP, MAC, gateway, DNS  |
| `Get-BatteryInformation`    | `Win32_Battery`          | Battery name, charge, status     |
| `Get-SecurityInformation`   | `Get-MpComputerStatus` + | Defender, Firewall, Activation   |
|                             | `Get-NetFirewallProfile` |                                  |

All collection functions use `Invoke-SafeQuery` to return "Not Available" on failure
instead of throwing errors.

### 3. Data Processing Layer

- `Invoke-SafeQuery` -- Safe script block execution with fallback
- `Convert-WmiDate` -- WMI datetime to readable format
- `Format-FileSize` -- Bytes to human-readable size
- `Get-StatusBadgeClass` -- Status string to CSS class mapping
- `Get-SectionIcon` -- Section name to emoji mapping

### 4. Report Generation Layer

#### HTML Output (`Build-HtmlReport`)

- Responsive CSS grid layout
- Dark theme with cyan accent colors
- System summary cards, detailed info tables
- Storage usage progress bars
- Security status badges
- Refresh button with live re-scan via XHR to `/scan`
- Print-friendly stylesheet
- Self-contained (all CSS/JS embedded, no external dependencies)

#### JSON Output (`Export-InventoryJson`)

- Structured JSON with top-level keys: `system`, `cpu`, `ram`, `gpu`, `disk`,
  `motherboard`, `bios`, `network`, `battery`, `security`
- Includes `metadata` object with tool version, scan date, computer name
- Output depth: 10 levels
- Encoding: UTF-8

### 5. HTTP Server Layer (`Start-KBUHttpServer`)

- Uses `System.Net.HttpListener` (native .NET, no external modules)
- Port scanning from configured start port (default: 58080)
- Serves initial HTML report on all requests
- `/scan` endpoint triggers a full re-scan and returns updated HTML
- Blocking loop; stops on `Ctrl+C` or window close

## Execution Flow

```
Main()
  |
  +-- Phase 1: Collect all data
  |       (10 collection functions run sequentially)
  |
  +-- Phase 2: Generate reports
  |       Build-HtmlReport()
  |       Export-InventoryJson()
  |       Save HTML to disk
  |
  +-- Phase 3: Live HTTP server
  |       Start-KBUHttpServer() (blocking)
  |         |-- Listen for requests
  |         |-- /scan: re-collect data, rebuild HTML
  |         |-- / (any): serve current HTML
  |
  +-- Phase 4: Console summary (after server stops)
```

## Configuration Flow

```
Script starts
  |
  +-- Read config.json from $PSScriptRoot/../config.json
  |
  +-- config.json exists?
  |     YES: parse JSON, validate fields
  |     NO:  show warning, use defaults
  |
  +-- Resolve output path
  |     Config value or default: C:\Users\Public\Desktop
  |
  +-- Resolve server port
  |     Config value or default: 58080
  |
  +-- Resolve version
  |     Config value or default: "2.1.0"
```

## Design Principles

- **Read-only:** No system modifications
- **Fail-safe:** All queries wrapped in try/catch, return "Not Available"
- **No admin required:** Uses .NET DriveInfo instead of admin-only storage APIs
- **Self-contained:** HTML report has no external CSS/JS/font dependencies
- **Configurable:** All paths and ports externalized to config.json
- **Dual output:** Both human-readable HTML and machine-readable JSON
- **Modular:** Separation of concerns between collection, processing, and rendering
