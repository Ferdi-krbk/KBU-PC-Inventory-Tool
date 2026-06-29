# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.1.0] - 2026-07-01

### Added
- `config.json` for externalized configuration (output path, port, filename, auto-open)
- JSON export alongside HTML report via `Export-InventoryJson` function
- Pester tests for hardware data collection and configuration validation
- Architecture documentation in `docs/architecture.md`
- Organized project structure with `src/`, `docs/`, `tests/` directories

### Changed
- Main script moved to `src/KBU_PC_Inventory.ps1`
- Report output path configurable via `config.json` (default: `C:\Users\Public\Desktop`)
- HTTP server port configurable via `config.json` (default: 58080)
- Version number sourced from `config.json`
- Auto-open browser behavior respects `auto_open` setting

### Fixed
- Corrected variable reference `$sec` to `$securityInfo` in main execution
- Removed duplicate `Build-HtmlReport` call

## [2.0.0] - 2026-06-28

### Added
- Live refresh feature via HTTP server
- Refresh button in HTML dashboard with XHR-based re-scan
- GPU information collection (`Get-GPUInformation`)
- Security section (Defender status, Firewall, Windows Activation)
- Battery information for laptops
- Network adapter details (MAC, IPv4, Gateway, DNS, Link Speed)
- Toast notifications in browser UI
- Responsive CSS grid layout
- Print-friendly stylesheet

### Changed
- Migrated from static file output to live HTTP server mode
- Upgraded HTML dashboard to modern dark theme design
- Improved error handling with `Invoke-SafeQuery` wrapper
- Extended status badge system

## [1.0.0] - 2026-06-25

### Initial Release
- Hardware inventory collection (CPU, RAM, Disk)
- Operating system information (edition, version, build, uptime)
- Motherboard and BIOS information
- Network adapter detection
- HTML report generation with embedded CSS
- Read-only operation guarantee
