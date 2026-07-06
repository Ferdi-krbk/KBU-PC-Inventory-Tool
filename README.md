# KBU PC Inventory Tool

A professional, read-only PowerShell-based IT inventory application for Windows
10/11 workstations. Collects hardware, OS, network, and security data, then
generates an interactive HTML dashboard with live refresh and structured JSON
export.

**Version:** 2.2.0  
**Author:** Karabuk University IT Department  
**License:** MIT

---

## Quick Start

**Double-click `run_inventory.bat`** — no setup required.

```powershell
# Or run directly via PowerShell
.\src\KBU_PC_Inventory.ps1
```

The tool will collect data, generate HTML + JSON reports, start a local HTTP
server, and open the dashboard in your browser.

---

## Features

| Category       | Collected Data                                           |
|----------------|----------------------------------------------------------|
| **System**     | OS edition, version, build, architecture, install date, uptime |
| **CPU**        | Name, manufacturer, cores, threads, max clock, current usage |
| **RAM**        | Total/available/used, per-module details (capacity, speed) |
| **GPU**        | Name, VRAM, driver version (dedicated + integrated)      |
| **Storage**    | Drive letters, capacity, free/used space, usage percent  |
| **Motherboard**| Manufacturer, model, serial number                       |
| **BIOS**       | Manufacturer, version, release date                      |
| **Network**    | Adapters, MAC, IPv4, gateway, DNS, link speed, internet  |
| **Security**   | Defender, Firewall profiles, Windows Activation          |
| **Battery**    | Charge percentage, power state (laptops only)            |

- **Live Refresh** — HTTP server with one-click browser re-scan
- **Dual Output** — HTML dashboard + structured JSON export
- **Configuration** — External `config.json` for paths, ports, and settings
- **Read-Only** — Zero system modifications, no admin required

---

## Project Structure

```
KBU-PC-Inventory-Tool/
├── run_inventory.bat            # Double-click launcher
├── config.json                  # Runtime configuration
├── CHANGELOG.md                 # Version history
├── README.md
├── LICENSE
├── .gitignore
│
├── src/
│   ├── KBU_PC_Inventory.ps1     # Main entry point — dot-sources modules, runs Main()
│   ├── Config.ps1               # Emoji constants, config.json loading, safe defaults
│   ├── Logger.ps1               # Timestamped log output (Info/Warning/Error/Success)
│   ├── Collectors.ps1           # Hardware/OS data collection (10 functions)
│   ├── Network.ps1              # Network adapter and connectivity information
│   ├── Security.ps1             # Defender, Firewall, Windows Activation
│   ├── ReportRenderer.ps1       # HTML dashboard generation (Build-HtmlReport)
│   ├── Export.ps1               # JSON export — independently testable
│   └── Server.ps1               # HTTP live refresh server (System.Net.HttpListener)
│
├── docs/
│   ├── architecture.md          # Full architecture breakdown
│   └── TESTING.md               # Testing strategy and coverage
│
├── tests/
│   └── inventory.tests.ps1      # 30+ Pester integration tests
│
└── screenshots/                  # Dashboard UI screenshots
```

---

## Module Architecture

```
run_inventory.bat
        ↓
KBU_PC_Inventory.ps1  (dot-sources all modules)
        ↓
Config.ps1  →  Collectors.ps1  →  Network.ps1  →  Security.ps1
        ↓
ReportRenderer.ps1  +  Export.ps1
        ↓
HTML Report  +  JSON Export  +  Server.ps1 (live refresh)
```

See [docs/architecture.md](docs/architecture.md) for the full layer-by-layer breakdown.

---

## Configuration

Edit `config.json` to customize behavior:

```json
{
  "version": "2.2.0",
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

| Setting                    | Description                                    |
|----------------------------|------------------------------------------------|
| `report.output_path`       | Directory for output files                     |
| `report.filename`          | Base filename (`.html` and `.json` appended)   |
| `report.auto_open`         | Auto-open browser after server starts          |
| `server.port`              | Starting HTTP port (scans next 9 if busy)      |
| `server.refresh_interval`  | Reserved for future timer-based refresh        |

If `config.json` is missing or invalid, safe default values are used with a
warning printed to the console.

---

## Output Files

Generated in the configured output directory:

| File                         | Purpose                                        |
|------------------------------|------------------------------------------------|
| `KBU_Inventory_Report.html`  | Interactive HTML dashboard with live refresh   |
| `KBU_Inventory_Report.json`  | Structured machine-readable inventory data     |

### JSON Export Structure

```json
{
  "metadata": { "tool_version": "2.2.0", "scan_date": "...", "computer_name": "..." },
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

The JSON output enables integration with asset management systems, CMDBs,
Elasticsearch, Power BI, and other automation tools.

---

## Testing

30+ Pester integration tests validate hardware collection, configuration
parsing, and JSON export using real CIM queries against the local machine.

```powershell
# Install Pester if needed
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester -Path .\tests\inventory.tests.ps1
```

See [docs/TESTING.md](docs/TESTING.md) for the full testing strategy.

---

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later (included with Windows)
- No admin privileges required

---

## Screenshots

`screenshots/dashboard.png` · `screenshots/hardware.png`  
`screenshots/network.png` · `screenshots/security.png`

---

## Future Improvements

- Timer-based automatic refresh
- CSV export format
- Remote collection agent mode (WinRM)
- SQLite/PostgreSQL storage backend
- Scheduled task integration for periodic inventory

---

## License

MIT License — See [LICENSE](LICENSE) for details.
