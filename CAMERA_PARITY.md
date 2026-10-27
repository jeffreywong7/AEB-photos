# Camera parity status

The target is a photo-only camera as close as possible to the native iPhone 15 Pro Camera, with AEB added. The supplied screenshots and Apple's guides define the reference in [native-camera-reference.md](docs/native-camera-reference.md). The goal is not yet complete.

## Current evidence

The native Debug and Release builds, layout/level checks, ImageIO crop/orientation/ISO checks, screenshot export, and all ten UI interaction cases pass at `99fb9cf`. Square and wide simulator screenshots were inspected. The next verification run adds focus-lock interactions and a locked-camera screenshot. [CI run](https://github.com/jeffreywong7/real-estate-photos/actions/runs/40481154948).

| Area | Implemented | Verified | Still required |
| --- | --- | --- | --- |
| Photo layout | Centered toolbar, 4:3 frame, separate shutter/footer rows, circular controls, PHOTO pill, iOS 26+ Liquid Glass | Layout anchors checked; simulator photo, focal, wheel, AEB, timer, and review images inspected | Final comparison on the reference iPhone |
| Zoom | Device-supported combined-camera stops, curved wheel, 24/28/35 mm main-camera crop cycling | Hold-to-open, preview dismissal, and focal cycling pass touch tests | Physical lens selection, zoom motion, and saved framing |
| AEB and flash | Frame count, EV spacing, center exposure, supported-range checks; Auto/On/Off flash for single photos | AEB switch changes shutter mode in touch tests; flash code compiles | Capture complete brackets, verify exposure values, test flash output |
| Composition | Grid and motion-driven horizon level with alignment feedback | Gravity math checked; level rendered in the simulator | Physical tilt direction and haptics |
| Exposure and focus | Tap-to-focus, exposure sun, exposure controls; touch-and-hold AE/AF lock waits for observed settled modes | Slider direction and toolbar value agree in touch tests; focus-lock checks pending | Physical focus, exposure lock, and AEB stability after recomposing |
| Aspect | 4:3, 1:1, and 16:9 framing with matching JPEG center crops | Touch capture produces square/wide dimensions; ImageIO checks preserve orientation and ISO; uncropped data is unchanged | Real-camera framing comparison |
| Timer | Off/3/5/10-second options and cancellation | Cancel/restart and background cancellation pass touch tests | Actual delayed capture on iPhone |
| Hardware shutter | Supported iOS 18+ capture-event API routed through the shutter action | Native compilation | Volume-button delivery and timer cancellation on iPhone |
| Photo review | Paging, thumbnail strip, pinch/double-tap zoom, drag-down dismissal, original-JPEG sharing and information | Double-tap zoom, back navigation, drag dismissal, and original-dimension checks pass | Verify original sharing on iPhone |
| Startup and permissions | Start on appearance, observe actual session state, preserve temporary inactivity, Settings/retry actions | Native compilation; UI fixture launches successfully | Cold launch, permission approval/denial, interruption, and real-session resume |

## Remaining implementation gaps

- Native photo-library browsing. Review currently contains only the latest capture from the current app session.

## Device validation

The local host has no Xcode or accessible iPhone. CI runs macOS/Xcode builds and simulator tests with the real camera UI and a debug-only neutral fixture. Those tests do not prove physical capture or permission handling.

On the iPhone, check cold launch before backgrounding, first camera permission approval, returning from Control Center, background/foreground transitions, switching cameras, photo review and return, valid and invalid AEB ranges, and Photos permission denial. Check flash with AEB off in bright and dark scenes. Check each available lens, wheel dragging, focal-length cycling, focus/exposure, level/haptics, and timer/volume-button capture. Compare saved images with the preview and confirm every requested exposure appears in Photos.

The original reference photos remain local and are not included in the repository or CI artifacts.

## Aspect-ratio follow-up

The viewfinder supports 4:3, 1:1, and 16:9 while retaining the measured toolbar/shutter/footer anchors. Each capture snapshots its selected aspect; JPEG processing applies the matching center crop to every exposure before saving. A 4:3 image that needs no crop retains its original bytes. Crop geometry accounts for EXIF rotation, and the encoder preserves orientation and exposure metadata. Geometry/ImageIO checks and the touch test checking square/wide output dimensions pass at `99fb9cf`. Real-camera framing still needs the device comparison.

## Focus-lock follow-up

Touch and hold meters the selected point once, then displays AE/AF LOCK after observing locked focus/exposure modes and completed adjustments. A five-second failure releases metering and reports the problem. Tapping the preview refocuses; stopping the camera or switching cameras restores automatic metering. Single photos use speed prioritization while locked so image fusion does not override the locked exposure. AEB continues to use EV-bias bracket settings on the combined camera; this preserves access to its physical lenses. Confirm the locked reference and each bracket's actual exposure on an iPhone before treating this as verified capture behavior.
