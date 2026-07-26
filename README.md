# 🚀 MacBook Optimization Script v2.0

## 📋 Overview

**MacBook Optimization Script** is an enterprise-ready, modular toolkit for macOS built to optimize system kernel settings, clear storage, tune network stack parameters, manage power profiles, perform hardware diagnostics, and maintain system performance.

Version 2.0 introduces **multi-system compatibility** (**Apple Silicon M1/M2/M3/M4** and **Intel**), **Signed System Volume (SSV)** protection, **APFS volume verification**, **exact user backup and rollback**, **multilingual UI (English & Spanish)**, **structured logging**, **non-interactive CLI automation**, **dry-run simulation mode**, and an **integration test suite**.

---

### 🌟 Key Enhancements

- 💻 **Multi-System Compatibility:** Native support for macOS 10.15 (Catalina) through macOS 15+ (Sonoma/Sequoia), Apple Silicon (`arm64`), and Intel (`x86_64`).
- 🛡️ **Dry-Run Mode (`--dry-run`):** Preview commands without modifying system settings.
- 💾 **Exact State Backup & Restore:** Automatically backs up modified `defaults`, `sysctl`, and `pmset` keys before applying changes.
- 🤖 **CLI Automation:** Non-interactive execution for dotfiles, CI/CD, and MDM (`--all`, `--module`, `--status`, `--rollback`).
- 📜 **Structured Logging:** Tracks execution events in `~/.macbook_optimizer.log`.
- 🌐 **Multilingual UI (i18n):** Real-time language switching between English and Spanish.
- 🧪 **Test Suite:** Built-in integration test suite (`tests/test_modules.sh`).

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/koding88/MacBook-Optimization-Script.git

# Navigate to directory
cd MacBook-Optimization-Script

# Grant execution permissions
chmod +x script.sh fix_permissions.sh tests/test_modules.sh

# Run interactive optimization menu
./script.sh
```

---

## 💻 CLI Usage & Command Flags

```bash
# Run simulation mode (preview commands without making changes)
./script.sh --dry-run --module system

# Run all safe optimizations non-interactively
./script.sh --all

# Run specific optimization module
./script.sh --module network

# Display non-interactive system status report
./script.sh --status

# Restore system settings from exact backup or defaults
./script.sh --rollback

# Set interface language (es: Spanish, en: English)
./script.sh --lang es

# Run integration test suite
./tests/test_modules.sh
```

---

## 🏗️ Architecture & Modules

```
MacBook-Optimization-Script/
├── script.sh                   # Main script entry point & CLI parser
├── fix_permissions.sh          # Permissions repair utility for state file
├── tests/
│   └── test_modules.sh         # Automated test suite
├── modules/
│   ├── sys_compat.sh           # OS, Architecture, SIP & SSV detection
│   ├── logger.sh               # Structured logging (~/.macbook_optimizer.log)
│   ├── i18n.sh                 # Multilingual translation dictionary (ES / EN)
│   ├── backup.sh               # User preference backup before modifications
│   ├── config.sh               # Configuration, safe read/write & status logging
│   ├── rollback.sh             # Revert optimizations back to backup or defaults
│   ├── ui_components.sh        # ANSI colored UI rendering & system info header
│   ├── menu_handler.sh         # User input router (options 0-29)
│   ├── system_optimizations.sh # Kernel sysctl tuning, memory purging, SSD tweaks
│   ├── network_optimizations.sh# Network stack parameters, DNS flushing, firewall
│   ├── storage_optimizations.sh# Cache cleanup, font caches, DS_Store removal
│   ├── performance_tweaks.sh   # Spotlight, Dashboard version-check, animations, Dock
│   ├── maintenance.sh          # APFS volume verification, periodic scripts, log truncation
│   ├── system_monitoring.sh    # CPU, Memory, GPU, Battery, Disk & Temperature stats
│   └── power_management.sh     # Low power mode toggle, AutoBoot (Intel), MDM detection
└── README.md
```

---

## 🛠️ Optimizations Summary

| Module | Feature | Description |
| :--- | :--- | :--- |
| **System** | Kernel Sysctl Tuning | Optimizes `maxvnodes`, `maxproc`, `maxfiles`, and IPC socket limits. |
| **Memory** | RAM Purge & Cache Flush | Purges inactive RAM pages and flushes disk buffers via `sync`. |
| **Storage** | Cache & `.DS_Store` Cleanup | Safely clears user/system caches and cleans hidden `.DS_Store` files. |
| **Network** | TCP & DNS Tuning | Sets `delayed_ack=0`, blackhole routing, and flushes `mDNSResponder`. |
| **Performance** | Animations & Dock | Speeds up window resizing, launch animations, and Dock hide/show delays. |
| **Maintenance** | APFS Volume Check | Modern `diskutil verifyVolume` replacement for legacy permission checks. |
| **Power** | Low Power & AutoBoot | Toggles Low Power Mode and manages lid auto-start (Intel Macs). |
| **Rollback** | Revert to Backup / Defaults | Restores native user preferences from backup file or macOS defaults. |

---

## 🔒 Security & System Requirements

- **Supported OS:** macOS 10.15 (Catalina) through macOS 15+ (Sequoia).
- **Privileges:** Standard user with `sudo` administrative rights when applying system tweaks.
- **Safety:** Non-destructive; protected system files are preserved on SSV-enabled releases.

---

## 📝 License

Distributed under the MIT License. See `LICENSE` for details.
