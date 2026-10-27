# Camera parity status

The goal remains a photo-only app that looks and behaves identically to the built-in iPhone Camera, with AEB settings. The current implementation is incomplete. Source parsing does not prove that the app builds, runs, or matches Camera.

## Implementation audit

| Requirement | Current source | Evidence still needed |
| --- | --- | --- |
| Photo-only Camera layout | `CameraView` has a full-width 4:3 viewfinder, PHOTO label, centered shutter, thumbnail, camera switch, and yellow accents. Compact screens put the toolbar over the preview. | Build and compare both apps on the same iPhone and iOS version. Check positions, safe areas, typography, colors, transitions, and shutter feedback. |
| Accessible AEB controls | The AEB drawer exposes frame count, EV spacing, center exposure, and a composition grid. `CameraModel` rejects unsupported frame counts and exposure biases. | Capture complete brackets at valid ranges. Check unavailable frame counts, invalid ranges, and the saved exposures in Photos. |
| Native lens controls | Rear-camera discovery prefers combined cameras. The zoom stops use device switch-over factors. An AEB-incompatible combined camera falls back to the wide camera. | Check actual lens selection, field of view, zoom transitions, and AEB support on each available camera. |
| Focus and exposure interactions | Tap-to-focus and a draggable exposure sun are implemented. Long-press AE/AF lock is absent. | Implement and exercise AE/AF lock with AEB. Confirm the preview and bracket center describe the same exposure. |
| Native photo review | A page view shows the last saved bracket during the current app session. | Native photo-library browsing and the built-in review interactions remain unmatched. |
| Other still-photo controls | Timer, aspect-ratio selection, and hardware shutter handling are absent. | Match the target iPhone's still-photo controls and verify their interaction with AEB. Video and panorama remain outside the requested scope. |
| Permissions and lifecycle | Camera and add-only Photos permission requests, session stop/restart, and capture/save error messages exist. | Exercise denials, camera interruptions, background/foreground transitions, photo review, and resuming capture. |

## Verification available here

The Swift sources pass a Tree-sitter syntax parse, and `git diff --check` passes. No iOS compilation or runtime tests have run.

The host is Linux. Neither `swift` nor `xcodebuild` is installed. The device tool returns `Agent device access is turned off for this environment.` This limitation was rechecked after the implementation passes.

## Resume on iOS

Use a macOS host with Xcode and an accessible iPhone. Record the iPhone model and iOS version as the visual and behavioral reference. First build the existing changes, fix compiler or runtime failures, and compare the camera screens. Then complete the missing interactions above and verify capture/save behavior on the same device.
