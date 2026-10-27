# Camera parity status

The target is a photo-only camera as close as possible to the native iPhone 15 Pro Camera, with AEB added. The supplied screenshots and Apple's guides define the reference in [native-camera-reference.md](docs/native-camera-reference.md). The goal is not yet complete.

## Current evidence

The native Debug and Release builds, layout/level checks, screenshot export, and all nine UI interaction cases pass at `727bec0`. The next verification run also covers aspect selection and JPEG crop behavior. [CI run](https://github.com/jeffreywong7/real-estate-photos/actions/runs/40455327032).

| Area | Implemented | Verified | Still required |
| --- | --- | --- | --- |
| Photo layout | Centered toolbar, 4:3 frame, separate shutter/footer rows, circular controls, PHOTO pill, iOS 26+ Liquid Glass | Layout anchors checked; simulator photo, focal, wheel, AEB, timer, and review images inspected | Final comparison on the reference iPhone |
| Zoom | Device-supported combined-camera stops, curved wheel, 24/28/35 mm main-camera crop cycling | Hold-to-open, preview dismissal, and focal cycling pass touch tests | Physical lens selection, zoom motion, and saved framing |
| AEB and flash | Frame count, EV spacing, center exposure, supported-range checks; Auto/On/Off flash for single photos | AEB switch changes shutter mode in touch tests; flash code compiles | Capture complete brackets, verify exposure values, test flash output |
| Composition | Grid and motion-driven horizon level with alignment feedback | Gravity math checked; level rendered in the simulator | Physical tilt direction and haptics |
| Exposure and focus | Tap-to-focus, exposure sun, exposure controls | Slider direction and toolbar value agree in touch tests | Physical focus and exposure; long-press AE/AF lock is absent |
| Timer | Off/3/5/10-second options and cancellation | Cancel/restart and background cancellation pass touch tests | Actual delayed capture on iPhone |
| Hardware shutter | Supported iOS 18+ capture-event API routed through the shutter action | Native compilation | Volume-button delivery and timer cancellation on iPhone |
| Photo review | Paging, thumbnail strip, pinch/double-tap zoom, drag-down dismissal, original-JPEG sharing and information | Double-tap zoom, back navigation, and drag dismissal pass; original dimensions confirmed in the rendered info sheet | Finish metadata test rerun; verify original sharing on iPhone |
| Startup and permissions | Start on appearance, observe actual session state, preserve temporary inactivity, Settings/retry actions | Native compilation; UI fixture launches successfully | Cold launch, permission approval/denial, interruption, and real-session resume |

## Remaining implementation gaps

- Long-press AE/AF lock and its interaction with AEB.
- Native photo-library browsing. Review currently contains only the latest capture from the current app session.

## Device validation

The local host has no Xcode or accessible iPhone. CI runs macOS/Xcode builds and simulator tests with the real camera UI and a debug-only neutral fixture. Those tests do not prove physical capture or permission handling.

On the iPhone, check cold launch before backgrounding, first camera permission approval, returning from Control Center, background/foreground transitions, switching cameras, photo review and return, valid and invalid AEB ranges, and Photos permission denial. Check flash with AEB off in bright and dark scenes. Check each available lens, wheel dragging, focal-length cycling, focus/exposure, level/haptics, and timer/volume-button capture. Compare saved images with the preview and confirm every requested exposure appears in Photos.

The original reference photos remain local and are not included in the repository or CI artifacts.

## Aspect-ratio follow-up

The viewfinder now supports 4:3, 1:1, and 16:9 while retaining the measured toolbar/shutter/footer anchors. Each capture snapshots its selected aspect; JPEG processing applies the matching center crop to every exposure before saving. A 4:3 image that needs no crop retains its original bytes. Crop geometry accounts for EXIF rotation, and the encoder preserves orientation and exposure metadata. Pure geometry/ImageIO checks and a touch test checking square/wide output dimensions are included in the next CI run. Real-camera framing still needs the device comparison.
