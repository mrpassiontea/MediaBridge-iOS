#!/bin/bash
if ! command -v xcodegen &> /dev/null; then
    echo "XcodeGen not found. Installing via Homebrew..."
    brew install xcodegen
fi

echo "Generating Xcode project..."
xcodegen generate
echo "Done! Opening project..."
open MediaBridge.xcodeproj
