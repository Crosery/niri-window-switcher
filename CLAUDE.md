# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A GTK4-based window switcher for the Niri Wayland compositor. Uses gtk4-layer-shell for overlay display and fuzzy-matcher for search filtering.

## Build & Run

```bash
# Build release binary
cargo build --release

# Run directly
cargo run

# Install to system
cp target/release/niri-switcher ~/.local/bin/niri-window-switcher
```

## Architecture

Single-file application (`src/main.rs`) with two main components:

1. **Window enumeration**: Parses `niri msg windows` output to extract window ID, title, app ID, and workspace
2. **GTK4 UI**: Layer-shell overlay window with search entry and scrollable list

The app uses gtk4-layer-shell to display as an overlay (Layer::Overlay) with exclusive keyboard input, similar to rofi/dmenu behavior.

## Dependencies

- `gtk4` - UI framework
- `gtk4-layer-shell` - Wayland layer-shell protocol for overlay windows
- `fuzzy-matcher` - Search filtering (currently imported but not yet implemented)

## Integration

Installed components:
- Binary: `~/.local/bin/niri-window-switcher`
- Keybindings configured in: `~/.config/niri/binds.kdl`
