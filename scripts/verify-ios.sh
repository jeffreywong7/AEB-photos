#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "iOS verification requires macOS with Xcode installed." >&2
    exit 1
fi
build_dir="${BRACKET_BUILD_DIR:-$PWD/.build/ios}"
mkdir -p "$build_dir"
xcrun swiftc Bracket/Bracket/CameraLayout.swift Bracket/Bracket/CameraLevelReading.swift Bracket/Bracket/PhotoAspect.swift Bracket/Bracket/PhotoCrop.swift Bracket/Bracket/RecentCaptureStore.swift tests/CameraLayout/main.swift -o "$build_dir/check-camera-layout"
"$build_dir/check-camera-layout"
for configuration in Debug Release; do
xcodebuild \
    -project Bracket/Bracket.xcodeproj \
    -scheme Bracket \
    -configuration "$configuration" \
    -derivedDataPath "$build_dir" \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
done
