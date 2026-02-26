#!/bin/bash
set -e

echo "Building release executable..."
swift build -c release

echo "Creating App Bundle..."
APP_DIR="/Applications/NotesApp.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "Copying executable and Info.plist..."
cp .build/release/NotesApp "$APP_DIR/Contents/MacOS/NotesApp"
cp Info.plist "$APP_DIR/Contents/Info.plist"

echo "Successfully installed NotesApp to /Applications!"
echo ""
echo "IMPORTANT: The app relies on a global hotkey, which means macOS will"
echo "ask you to grant it Accessibility permissions in System Settings -> Privacy & Security."
