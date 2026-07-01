# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.1.0] - 2026-07-01

### Added
- `run_inventory.bat` — double-click batch launcher for non-technical users
- `config.json` — externalized runtime configuration (output path, port, filename, auto-open)
- JSON export (`Export-InventoryJson`) — structured machine-readable output alongside HTML
- Pester test suite — 30+ tests covering config parsing, hardware collection, and JSON structure
- Architecture documentation — detailed layer breakdown in `docs/architecture.md`

### Changed
- Main script moved into `src/KBU_PC_Inventory.ps1` for clean project structure
- Report output path configurable via `config.json` (default: `C:\Users\Public\Desktop`)
- HTTP server start port configurable via `config.json` (default: 58080)
- Tool version sourced from `config.json` (displayed in HTML footer and console header)
- Browser auto-open controlled by `report.auto_open` setting

### Fixed
- Variable reference `$sec` corrected to `$securityInfo` in main execution flow
- Removed duplicate `Build-HtmlReport` invocation that generated the report twice
- Phase 4 browser launch now respects `auto_open` configuration

## [2.0.0] - 2026-06-28

### Added
- Live HTTP server with browser-based dashboard
- XHR-based refresh button — re-scan without restarting the tool
- GPU information collection (dedicated + integrated)
- Security section (Windows Defender status, Firewall profiles, Windows activation)
- Battery information for laptops (charge percentage, power state)
- Network adapter details (MAC address, IPv4, default gateway, DNS servers, link speed)
- Toast notification system in the browser UI
- Responsive CSS grid layout (adapts to mobile and tablet screens)
- Print-optimized stylesheet

### Changed
- Transitioned from static HTML file output to live server mode
- Upgraded HTML dashboard to dark theme with cyan accent design (`#0f1923` / `#00b4d8`)
- All data collection wrapped in `Invoke-SafeQuery` with `"Not Available"` fallback
- Extended status badge system (green/yellow/red pills)

## [1.0.0] - 2026-06-25

### Initial Release
- CPU, RAM, and disk hardware inventory collection
- Operating system information (edition, version, build number, architecture, uptime)
- Motherboard and BIOS information
- Network adapter detection
- Self-contained HTML report with embedded CSS
- Read-only guarantee — zero system modifications
- Released under MIT License
