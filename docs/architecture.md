# KBU PC Inventory Tool -- Architecture

## Project Purpose

The KBU PC Inventory Tool is a read-only PowerShell-based IT auditing application
developed for the Karabuk University IT Department.

### Why This Tool Exists

The IT department manages hundreds of Windows workstations across campus. Before
deploying software, applying updates, or troubleshooting, technicians need to
know exactly what hardware and OS each machine has.

This tool solves that problem by collecting and presenting a complete system
snapshot in a single run. No remote agents, no installers, no admin permissions
required. Just double-click `run_inventory.bat` and get a full HTML dashboard.

### Inventory Tool vs Deployment Validator

This repository is part of a larger IT toolset:

| Tool                          | Purpose                                    |
|-------------------------------|--------------------------------------------|
| **KBU PC Inventory Tool**     | Read current system state, generate report |
| **KBU Workstation Validator** | Enforce deployment standards, fix config   |

The Inventory Tool is *diagnostic only*. It never changes the system. The
Validator is *prescriptive* — it checks compliance and applies corrections.

## Architecture Overview

```
run_inventory.bat
        |
        v
src/KBU_PC_Inventory.ps1     <-- Entry point, orchestrates all phases
        |
        v
config.json                   <-- User-editable runtime configuration
        |
        v
Inventory Collection          <-- 10 CIM/WMI/.NET data-gathering functions
        |
        v
Data Processing               <-- Safe query wrappers, formatting, badge logic
        |
        v
HTML Renderer + JSON Exporter <-- Dual-format report generation
        |
        v
Desktop Output                <-- Saved to configured output path
        +
HTTP Live Server              <-- Optional: browser dashboard with re-scan
```

### Detailed Layer Diagram

```
+-------------------+
| run_inventory.bat |  <-- User double-clicks this
+--------+----------+
         |
         | PowerShell -ExecutionPolicy Bypass
         v
+--------+----------+
| config.json       |  <-- Reads output path, port, filename, version
+--------+----------+
         |
         v
+--------+----------+
| Inventory         |
| Collector         |  <-- CIM/WMI + .NET DriveInfo (no admin needed)
+--------+----------+
         |
         v
+--------+----------+
| Data Processor    |  <-- Safe query, date/size format, status badge CSS
+--------+----------+
         |
    +----+---------+
    |              |
    v              v
+---+---+    +----+----+
| HTML  |    | JSON    |  <-- Dual output: human + machine readable
| Render|    | Export  |
+---+---+    +----+----+
    |
    v
+---+---------------+
| HTTP Server        |  <-- Live refresh on /scan endpoint
| System.Net.Listener|
+--------------------+
         |
         v
+--------+----------+
| Desktop Output    |  <-- .html + .json files
+-------------------+
```

## Layers in Detail

### 1. Entry Point (`run_inventory.bat`)

A Windows batch file that serves as the double-click launcher:

- Detects its own location as the project root using `%~dp0`
- Verifies `PowerShell.exe` is available
- Verifies `src\KBU_PC_Inventory.ps1` exists
- Launches PowerShell with `-ExecutionPolicy Bypass -NoProfile -NoLogo`
- Shows readable error messages and pauses on failure
- No inventory logic in the batch file — pure launcher

### 2. Configuration Layer (`config.json`)

```json
{
  "version": "2.1.0",
  "report": {
    "output_path": "C:\\Users\\Public\\Desktop",
    "filename": "KBU_Inventory_Report",
    "auto_open": true
  },
  "server": {
    "port": 58080,
    "refresh_interval": 30
  }
}
```

**Fallback behavior:** If `config.json` is missing, unreadable, or malformed
JSON, every setting falls back to a safe hardcoded default. A warning is
printed to the console. The script never crashes due to missing configuration.

### 3. Data Collection Layer

Ten PowerShell functions gather system information using standard Windows APIs.
No third-party tools or admin elevation is required.

| Function                      | Source                     | Data Collected                        |
|-------------------------------|----------------------------|---------------------------------------|
| `Get-SystemInformation`       | `Win32_OperatingSystem`    | OS edition, version, build, arch, uptime |
| `Get-CPUInformation`          | `Win32_Processor`          | CPU name, manufacturer, cores, threads, clock |
| `Get-RAMInformation`          | `Win32_PhysicalMemory`     | Total/available/used RAM, per-module details |
| `Get-GPUInformation`          | `Win32_VideoController`    | GPU name, VRAM, driver version        |
| `Get-StorageInformation`      | `.NET DriveInfo`           | Drive letters, capacity, usage %, free space |
| `Get-MotherboardInformation`  | `Win32_BaseBoard`          | Manufacturer, model, serial number    |
| `Get-BIOSInformation`         | `Win32_BIOS`               | Manufacturer, version, release date   |
| `Get-NetworkInformation`      | `Win32_NetworkAdapter`     | Adapter name, IP, MAC, gateway, DNS, link speed |
| `Get-BatteryInformation`      | `Win32_Battery`            | Battery name, charge %, power status  |
| `Get-SecurityInformation`     | `Get-MpComputerStatus` + firewall | Defender status, firewall, Windows activation |

**Why `.NET DriveInfo` for storage?** `Win32_DiskDrive` and `Win32_LogicalDisk`
are reliable but require admin rights for some properties. `.NET DriveInfo`
(`[System.IO.DriveInfo]::GetDrives()`) provides capacity and free space for
every fixed drive without any elevation. This was a deliberate design choice
to keep the tool usable by all staff, not just administrators.

### 4. Data Processing Layer

Utility functions that sanitize and format raw data:

| Function               | Responsibility                                      |
|------------------------|-----------------------------------------------------|
| `Invoke-SafeQuery`     | Execute script block; return "Not Available" on error |
| `Convert-WmiDate`      | WMI datetime format (`20260625143000.000000+180`) → `yyyy-MM-dd HH:mm:ss` |
| `Format-FileSize`      | Raw bytes → human-readable (`1.5 TB`, `256 GB`)     |
| `Get-StatusBadgeClass` | Status string → CSS badge class (`ok`, `warn`, `error`) |
| `Get-SectionIcon`      | Section name → Unicode emoji character              |
| `New-HtmlTableRow`     | Label + value → `<tr>` HTML row                     |
| `New-HtmlBadge`        | Status text → `<span class="badge badge-ok">`       |

### 5. Report Generation Layer

#### HTML Report (`Build-HtmlReport`)

Generates a fully self-contained HTML5 document:

- **No external dependencies:** CSS and JavaScript are embedded inline
- **Dark theme:** `#0f1923` background with `#00b4d8` cyan accents
- **Responsive grid:** CSS Grid adapts from 2-column to single-column on mobile
- **System summary cards:** CPU, RAM, GPU, Disk, Windows, overall status at a glance
- **Storage progress bars:** Visual usage indicators with color coding (green/yellow/red)
- **Security badges:** Color-coded pills for Defender, Firewall, Activation
- **Live refresh:** JavaScript XHR button that calls `/scan` and replaces the DOM
- **Print stylesheet:** Optimized for paper — white background, hidden buttons
- **Toast notifications:** Non-blocking status messages in the top-center

#### JSON Export (`Export-InventoryJson`)

Produces structured machine-readable output:

```json
{
  "metadata": {
    "tool_version": "2.1.0",
    "scan_date": "2026-07-01 09:21:00",
    "computer_name": "DESKTOP-ABC123",
    "current_user": "ferdi"
  },
  "system": { ... },
  "cpu": { ... },
  "ram": { "modules": [ ... ] },
  "gpu": [ ... ],
  "disk": [ ... ],
  "motherboard": { ... },
  "bios": { ... },
  "network": { "adapters": [ ... ] },
  "battery": { ... },
  "security": { ... }
}
```

- **Depth:** `ConvertTo-Json -Depth 10` ensures deeply nested properties (e.g., RAM modules array) serialize correctly
- **Encoding:** UTF-8 for maximum compatibility
- **Use cases:** Import into CMDB, asset tracking databases, Elasticsearch, Power BI, or custom dashboards

### 6. HTTP Server Layer (`Start-KBUHttpServer`)

A lightweight HTTP server built on `System.Net.HttpListener`:

- **Port selection:** Scans from configured port upward (default: 58080-58089)
- **All routes:** Serve the current HTML report
- **`/scan` route:** Trigger full data re-collection, rebuild HTML, return updated page
- **Blocking loop:** Runs until `Ctrl+C` or window close
- **Browser launch:** Opens default browser automatically (controlled by `auto_open`)

#### Refresh Sequence

```
Browser clicks "Refresh Report"
  → XHR GET /scan
  → Server re-runs all 10 collection functions
  → Server calls Build-HtmlReport()
  → Server streams new HTML back
  → Browser replaces current page via document.write()
  → Toast: "Report refreshed successfully!"
```

## Error Handling Strategy

The tool is designed for non-technical users who should never see a red
PowerShell crash dump. Every data collection point uses `Invoke-SafeQuery`:

```powershell
$value = Invoke-SafeQuery -Label "CPU" -ScriptBlock {
    Get-CimInstance Win32_Processor | Select-Object -First 1
}
```

If the CIM call fails (permissions, missing class, timeout):
1. The exception is caught silently
2. `$value` becomes `"Not Available"`
3. The report renders normally with `"Not Available"` in that field
4. No crash, no interruption

The same pattern applies to file output, HTTP serving, and configuration loading.

## Future Integration Possibilities

The structured JSON output makes this tool integration-ready:

- **CMDB Import:** Scheduled task runs the tool on each workstation, JSON files
  ingested into an IT asset management database
- **Log Aggregation:** Ship JSON to Elasticsearch / Graylog for centralized searching
- **Power BI Dashboard:** Aggregate JSON exports across the fleet to visualize
  hardware distribution, disk usage trends, OS version compliance
- **CI/CD Pipeline:** Run inventory before deployment to verify target machine specs
- **REST API:** Extend the HTTP server to serve JSON at `/api/inventory`

## Design Principles

| Principle            | Implementation                                          |
|----------------------|---------------------------------------------------------|
| Read-only            | Zero write operations to disk, registry, or system      |
| Fail-safe            | All queries wrapped; `"Not Available"` instead of crash |
| No admin required    | `.NET DriveInfo`, no `Win32_DiskDrive` admin-only props |
| Self-contained HTML  | No CDN fonts, no external CSS/JS, works offline         |
| Configurable         | All paths and ports externalized to `config.json`        |
| Dual output          | Human-readable HTML + machine-readable JSON             |
| Modular              | Collection, processing, rendering are separate regions  |
| Portable             | Single folder — copy to USB and run anywhere            |
