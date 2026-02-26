# NotesApp

A minimal macOS menubar notes app with Markdown support.

## What it does

- Lives in the background as a menubar accessory (no Dock icon)
- Toggle visibility with `Cmd + Ctrl + N` from anywhere
- Edits a single Markdown file at `~/notes/main.md`
- Closing the window hides it rather than quitting
- Launches automatically at login

## Requirements

- macOS 14+
- Xcode / Swift toolchain

## Install

```bash
./install.sh
```

This builds a release binary, creates an `.app` bundle, and copies it to `/Applications`.

> **Note:** macOS will prompt for Accessibility permissions (required for the global hotkey) under System Settings → Privacy & Security.
