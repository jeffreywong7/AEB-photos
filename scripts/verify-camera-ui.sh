#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir="${BRACKET_BUILD_DIR:-$PWD/.build/ios}"
output_dir="$PWD/.build/camera-ui"
app_path="$build_dir/Build/Products/Debug-iphonesimulator/Bracket.app"
mkdir -p "$output_dir"
device_id="$(xcrun simctl create 'Bracket Camera UI' com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro)"
trap 'xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true; xcrun simctl delete "$device_id" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$device_id"
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app_path"
container="$(xcrun simctl get_app_container "$device_id" com.example.Bracket data)"
for state in photo wheel focal aeb timer square wide locked review; do
    xcrun simctl terminate "$device_id" com.example.Bracket >/dev/null 2>&1 || true
    xcrun simctl launch "$device_id" com.example.Bracket --camera-ui-preview --camera-ui-state "$state"
    python3 scripts/wait-for-camera-snapshot.py "$container/Documents/camera-$state.png" "$output_dir/window-$state.png"
    xcrun simctl io "$device_id" screenshot "$output_dir/camera-$state.png"
done
xcrun simctl addmedia "$device_id" "$output_dir/window-photo.png"
test_status=0
xcodebuild \
    -project Bracket/Bracket.xcodeproj \
    -scheme Bracket \
    -configuration Debug \
    -derivedDataPath "$build_dir" \
    -destination "platform=iOS Simulator,id=$device_id" \
    -resultBundlePath "$PWD/.build/camera-ui-tests.xcresult" \
    CODE_SIGNING_ALLOWED=NO \
    test || test_status=$?
if [[ -d "$PWD/.build/camera-ui-tests.xcresult" ]]; then
    xcrun xcresulttool export attachments \
        --path "$PWD/.build/camera-ui-tests.xcresult" \
        --output-path "$PWD/.build/camera-ui-attachments"
fi
mkdir -p "$PWD/.build/camera-ui-attachments"
xcrun simctl spawn "$device_id" log show --style compact --last 15m \
    --predicate 'subsystem == "com.example.Bracket" AND category == "CameraLevel"' \
    > "$PWD/.build/camera-ui-attachments/level-motion.log" || true
exit "$test_status"
