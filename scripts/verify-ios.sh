#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "iOS verification requires macOS with Xcode installed." >&2
    exit 1
fi
xcodebuild \
    -project Bracket/Bracket.xcodeproj \
    -scheme Bracket \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
