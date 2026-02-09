# ActionTrigger

ActionTrigger is a macOS Finder extension that adds configurable context menu actions for files and folders.

## What it does
- Adds custom right‑click actions in Finder
- Open items with user‑selected apps
- Run local scripts with the selected path as an argument
- Rules can target folders, file extensions, or common content types

## Components
- **ActionTrigger.app**: the configuration UI (SwiftUI)
- **FinderExtension.appex**: Finder Sync extension that builds the menu
- **ActionTriggerHelperXPC.xpc**: helper used to open files with apps

## Usage
1. Run **ActionTrigger.app** to configure rules and actions.
2. Enable the Finder extension in System Settings > Privacy & Security > Extensions > Finder.
3. Right‑click a file or folder in Finder to use the actions.

## Notes
- Script actions run with `/bin/zsh` and receive the selected path as the first argument.
- App and script paths are stored with security‑scoped bookmarks.

## Requirements
- macOS 15+
- Xcode (for building)
