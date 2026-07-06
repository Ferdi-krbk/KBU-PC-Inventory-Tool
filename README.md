# KBU PC Inventory Tool

A professional PowerShell-based IT inventory application that collects detailed
system information from Windows 10/11 workstations and generates a beautiful,
responsive HTML dashboard with live refresh capability and structured JSON export.

**Version:** 2.2.0
**Author:** Karabuk University IT Department
**License:** MIT

## Quick Start

**Double-click `run_inventory.bat`** — that's it.

The tool will:
1. Collect hardware and system information
2. Generate an HTML dashboard report
3. Export a JSON file for automation
4. Start a local HTTP server with live refresh
5. Open the dashboard in your default browser

For advanced users:
```powershell
.\src\KBU_PC_Inventory.ps1
```

## Features

- **Hardware Inventory:** CPU (name, cores, threads, clock), RAM (total/available/used, per-module details), GPU (name, VRAM, driver), Storage (capacity, usage %, free space), Motherboard, BIOS
- **System Information:** OS edition, version, build, architecture, install date, uptime
- **Network:** Active adapters, IPv4, MAC, gateway, DNS servers, link speed, internet status
- **Security:** Windows Defender, Firewall profiles, Windows Activation status
- **Battery:** Charge percentage and power state (laptops)
- **Live Refresh:** Built-in HTTP server with one-click browser re-scan
- **Dual Output:** Interactive HTML dashboard + structured JSON export
- **Configuration:** External `config.json` for paths, ports, and settings
- **Read-Only:** Zero system modifications

## Project Structure

```
KBU-PC-Inventory-Tool/
├── run_inventory.bat            # Double-click launcher
├── config.json                  # Runtime configuration
├── CHANGELOG.md                 # Version history
├── README.md                    # This file
├── LICENSE                      # MIT License
├── .gitignore
├── src/
│   ├── KBU_PC_Inventory.ps1     # Main entry point (dot-source orchestrator)
│   ├── Config.ps1               # Configuration loader with safe defaults
│   ├── Logger.ps1               # Timestamped log output
│   ├── Collectors.ps1           # Hardware/OS data collection functions
│   ├── Network.ps1              # Network adapter collection
│   ├── Security.ps1             # Defender, Firewall, Activation
│   ├── ReportRenderer.ps1       # HTML dashboard generation
│   ├── Export.ps1               # JSON export (independently testable)
│   └── Server.ps1               # HTTP live refresh server
├── docs/
│   └── architecture.md          # Architecture documentation
├── tests/
│   └── inventory.tests.ps1      # Pester test suite
└── screenshots/                  # UI screenshots
```

## Architecture

`run_inventory.bat` → `src/KBU_PC_Inventory.ps1` → `config.json` → Inventory Collection → Data Processing → HTML Report + JSON Export → Desktop Output

See [docs/architecture.md](docs/architecture.md) for the full layer-by-layer breakdown including the HTTP server, error handling strategy, data collection table, and future integration possibilities.

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

If `config.json` is missing or invalid, safe default values are used with a warning.

## Output Files

Generated in the configured output directory:

| File                         | Purpose                                          |
|------------------------------|--------------------------------------------------|
| `KBU_Inventory_Report.html`  | Interactive HTML dashboard with live refresh     |
| `KBU_Inventory_Report.json`  | Structured machine-readable inventory export     |

### JSON Export Structure

```json
{
  "metadata": {
    "tool_version": "2.2.0",
    "scan_date": "2026-07-01 09:00:00",
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

The JSON export enables integration with asset management systems, CMDBs,
Elasticsearch, Power BI, and other automation tools.

## Testing

30+ Pester integration tests validate hardware collection, configuration parsing, and JSON export
using real CIM queries against the local machine.

See [docs/TESTING.md](docs/TESTING.md) for the full testing strategy.

```powershell
# Install Pester if needed
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester -Path .\tests\inventory.tests.ps1
```

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later (included with Windows)
- No admin privileges required

## Screenshots

Screenshots of the HTML dashboard are available in the `screenshots/` directory:
`dashboard.png`, `hardware.png`, `network.png`, `security.png`

## Future Improvements

- Timer-based automatic refresh
- CSV export format
- Remote collection agent mode (WinRM)
- SQLite/PostgreSQL storage backend
- Scheduled task integration for periodic inventory
- Email report delivery
- Fleet-wide aggregation dashboard

## License

MIT License — See [LICENSE](LICENSE) for details.
