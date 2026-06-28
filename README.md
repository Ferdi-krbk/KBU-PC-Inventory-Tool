# KBU PC Inventory Tool

A professional PowerShell-based IT inventory application that collects detailed system
information from Windows 10/11 workstations and generates a beautiful, responsive
HTML dashboard report with live refresh capability.

**Version:** 2.1.0
**Author:** Karabuk University IT Department
**License:** MIT

## Features

- **Hardware Inventory:** CPU, RAM (modules), GPU, Storage, Motherboard, BIOS
- **System Information:** OS edition, version, build, architecture, uptime
- **Network:** Active adapters, IPv4, MAC, gateway, DNS, internet status
- **Security:** Windows Defender, Firewall, Activation status
- **Battery:** Charge percentage and status (laptops)
- **Live Refresh:** Built-in HTTP server with browser refresh button
- **Dual Output:** HTML dashboard + structured JSON export
- **Configuration:** External `config.json` for paths, ports, and settings
- **Read-Only:** No system modifications

## Project Structure

```
KBU-PC-Inventory-Tool/
├── src/
│   └── KBU_PC_Inventory.ps1    # Main script
├── tests/
│   └── inventory.tests.ps1     # Pester tests
├── docs/
│   └── architecture.md         # Architecture documentation
├── screenshots/                 # Screenshots (if any)
├── config.json                  # User configuration
├── CHANGELOG.md                 # Version history
├── .gitignore
├── LICENSE
└── README.md
```

## Quick Start

```powershell
# Run the inventory tool
.\src\KBU_PC_Inventory.ps1
```

The tool will:
1. Collect hardware and system information
2. Generate an HTML dashboard report
3. Export a JSON file for automation
4. Start a local HTTP server with live refresh
5. Open the dashboard in your default browser

## Configuration

Edit `config.json` to customize behavior:

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

| Setting                    | Description                                    |
|----------------------------|------------------------------------------------|
| `report.output_path`       | Directory for output files                     |
| `report.filename`          | Base filename (`.html` and `.json` appended)   |
| `report.auto_open`         | Auto-open browser after server starts          |
| `server.port`              | Starting port (scans next 9 ports if busy)     |
| `server.refresh_interval`  | Reserved for future timer-based refresh        |

If `config.json` is missing or invalid, safe default values are used with a warning.

## Output Files

The tool generates two output files in the configured directory:

- `KBU_Inventory_Report.html` -- Interactive HTML dashboard
- `KBU_Inventory_Report.json` -- Structured machine-readable export

### JSON Export Structure

```json
{
  "metadata": { "tool_version": "2.1.0", "scan_date": "...", "computer_name": "..." },
  "system": { ... },
  "cpu": { ... },
  "ram": { ... },
  "gpu": [ ... ],
  "disk": [ ... ],
  "motherboard": { ... },
  "bios": { ... },
  "network": { ... },
  "battery": { ... },
  "security": { ... }
}
```

The JSON export enables integration with asset management systems, CMDBs, and
other automation tools.

## Testing

Pester tests are included to validate hardware data collection:

```powershell
# Install Pester if not available
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run tests
Invoke-Pester -Path .\tests\inventory.tests.ps1
```

Tests verify:
- CPU, RAM, Disk, OS, Motherboard, BIOS data can be collected
- Configuration file is valid JSON with required fields
- JSON export structure contains expected keys

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later
- No admin privileges required

## Architecture

See [docs/architecture.md](docs/architecture.md) for detailed documentation on
the data collection, processing, rendering, and HTTP server layers.

## Screenshots

Screenshots can be added to the `screenshots/` directory.

## Future Improvements

- Timer-based automatic refresh
- CSV export format
- Remote collection agent mode
- Database storage backend
- Scheduled task integration
- Email report delivery

## License

MIT License -- See [LICENSE](LICENSE) for details.
