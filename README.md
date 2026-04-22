# MacBook Optimization

## Overview

MacBook Optimization is a native macOS SwiftUI app for running common Mac optimization and diagnostics tasks from a single interface. It includes step review, localized UI, status tracking, and structured result sheets for inspection-style actions.

- Native macOS app built with SwiftUI
- Step-by-step review before running action groups
- Toasts, activity feed, and in-app result sheets
- Status tracking persisted in `~/.macbook_optimizer_state.conf`
- CPU, memory, battery, GPU, disk, network, and thermal monitoring
- MDM inspection and AutoBoot / power utilities

## Quick Start

```bash
git clone https://github.com/koding88/MacBook-Optimization-Script.git
cd MacBook-Optimization-Script
cd macos-app
swift test
./build_app.sh
open "build/MacBook Optimization.app"
```

## 📚 Documentation

### System Requirements

-   macOS 10.15 (Catalina) or later
-   Administrative privileges
-   Xcode Command Line Tools / Swift toolchain

### Directory Structure

```
MacBook-Optimization-Script/
├── assets/              # Shared brand assets (icons, artwork)
├── docs/                # Repository notes and maintenance docs
├── macos-app/           # Native SwiftUI macOS application
│   ├── Sources/         # App source code
│   ├── Tests/           # Unit tests
│   ├── packaging/       # Packaging metadata for the macOS bundle
│   ├── scripts/         # Build/release/run script implementations
│   ├── build_app.sh     # Compatibility wrapper for local app bundle build
│   └── release_app.sh   # Compatibility wrapper for DMG/release packaging
└── dist/                # Built artifacts
```

Detailed layout notes live in [docs/repository-structure.md](docs/repository-structure.md).

## Features

### System Optimizations

-   CPU and Memory optimization
-   SSD performance tuning
-   Security enhancements
-   Power management optimization
-   AutoBoot toggle flow (Intel Macs)
-   MDM status detection

### Network Optimizations

-   TCP/IP stack optimization
-   DNS cache management
-   Firewall configuration
-   Network performance tuning

### Storage Optimizations

-   System cache cleanup
-   Unused language removal
-   Font cache optimization
-   .DS_Store file management

### Performance Tweaks

-   Spotlight indexing control
-   Animation optimization
-   Dashboard management
-   Dock performance tuning

### Monitoring and Diagnostics

-   Power saving mode toggle
-   CPU / Memory / Battery snapshots
-   GPU / Disk / Network / Thermal snapshots
-   MDM status detection
-   Optimization status tracking

## Status Tracking

The app includes a status tracking system that provides:

| Feature           | Description                               |
| ----------------- | ----------------------------------------- |
| Real-time Updates | Immediate feedback on optimization status |
| Activity Feed     | Track completed and failed actions        |
| Result Sheets     | Show structured output for inspections    |
| Timestamps        | Record when optimizations were performed  |
| Reset Support     | Clear persisted action states in-app      |

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. Fork the repository at https://github.com/koding88/MacBook-Optimization-Script/fork
2. Create your feature branch:
    ```
    git checkout -b feature/AmazingFeature
    ```
3. Commit your changes:
    ```
    git commit -m 'Add some AmazingFeature'
    ```
4. Push to the branch:
    ```
    git push origin feature/AmazingFeature
    ```
5. Open a Pull Request at https://github.com/koding88/MacBook-Optimization-Script/pulls

For more details, please see our [Contributing Guidelines](CONTRIBUTING.md).

## Security

Some actions require administrative privileges. Please:

-   Review the code before running
-   Keep your system up to date
-   Back up important data
-   Report security issues through our [Security Policy](SECURITY.md)

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

-   [Apple Developer Documentation](https://developer.apple.com/documentation/)
-   [MacOS Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2002/tn2002.html)
-   All [contributors](https://github.com/koding88/MacBook-Optimization-Script/graphs/contributors)

## Support

Need help? Here are some resources:

-   🐛 Report bugs in [Issues](https://github.com/koding88/MacBook-Optimization-Script/issues)
-   📧 Contact: [duongngocanh2k03@gmail.com](mailto:duongngocanh2k03@gmail.com)

---
