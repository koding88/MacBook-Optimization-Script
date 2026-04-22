# Repository Structure

This repository is organized so product source, packaging metadata, automation scripts, and brand assets stay easy to understand and maintain.

## Top level

- `assets/branding/`
  Shared brand assets used by packaging scripts. The app icon source lives here.
- `docs/`
  Repository-level documentation and maintenance notes.
- `dist/`
  Release artifacts produced by the packaging flow. This directory is ignored by Git.
- `macos-app/`
  The Swift package for the native macOS application.

## `macos-app/`

- `Sources/`
  SwiftUI app source code and bundled localized resources.
- `Tests/`
  Unit and presentation tests for the app.
- `packaging/macos/`
  Static packaging metadata, such as `Info.plist`, used when creating the `.app` bundle.
- `scripts/`
  Build, release, run, and helper scripts.
- `build/`
  Local bundle outputs created during packaging. This directory is ignored by Git.

## Compatibility wrappers

The following files remain at the root of `macos-app/` as thin wrappers so existing commands continue to work:

- `build_app.sh`
- `release_app.sh`
- `run_app.sh`
- `open_built_app.sh`
