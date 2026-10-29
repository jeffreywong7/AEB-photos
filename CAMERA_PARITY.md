# Camera parity status

The target is a photo-only camera as close as possible to the native iPhone 15 Pro Camera, with AEB added. The supplied screenshots and Apple's guides define the reference in [native-camera-reference.md](docs/native-camera-reference.md). The goal is not yet complete.

## Current evidence

At `ccbe462`, native Debug and Release builds, layout/level checks, ImageIO crop/orientation/ISO checks, capture-date metadata checks, storage checks, and all seventeen UI interactions pass. These include delayed restoration, empty/error recovery, unknown capture dates, relaunch recovery, and library PNG selection. [CI run](https://github.com/jeffreywong7/real-estate-photos/actions/runs/40498519084). A subsequent iPhone report identified a frozen horizon level. The changing-motion UI test failed on `c1812bb`: lifecycle logs showed that the activation callback read the captured inactive phase and never started sampling. The level now observes its combined enabled/active value and uses the callback's new value. The same correction is applied to camera lifecycle callbacks. Native verification of this correction is pending; physical motion and haptics still need an iPhone check.

| Area | Implemented | Verified | Still required |
| --- | --- | --- | --- |
| Photo layout | Centered toolbar, 4:3 frame, separate shutter/footer rows, circular controls, PHOTO pill, iOS 26+ Liquid Glass | Layout anchors checked; simulator photo, focal, wheel, AEB, timer, and review images inspected | Final comparison on the reference iPhone |
| Zoom | Device-supported combined-camera stops, curved wheel, 24/28/35 mm main-camera crop cycling | Hold-to-open, preview dismissal, and focal cycling pass touch tests | Physical lens selection, zoom motion, and saved framing |
| AEB and flash | Frame count, EV spacing, center exposure, supported-range checks; Auto/On/Off flash for single photos | AEB switch changes shutter mode in touch tests; flash code compiles | Capture complete brackets, verify exposure values, test flash output |
| Composition | Grid and live-sampled horizon level with alignment feedback and stale-sample rejection | Gravity math checked; changing-roll, alignment, flat-phone hiding, and resume checks added | Confirm moving level and haptics on the iPhone |
| Exposure and focus | Tap-to-focus, exposure sun, exposure controls; touch-and-hold AE/AF lock waits for observed settled modes | Touch tests lock, adjust EV, capture, unlock, and clear the lock on backgrounding; locked-camera screenshot inspected | Physical focus, exposure lock, and AEB stability after recomposing |
| Aspect | 4:3, 1:1, and 16:9 framing with matching JPEG center crops | Touch capture produces square/wide dimensions; ImageIO checks preserve orientation and ISO; uncropped data is unchanged | Real-camera framing comparison |
| Timer | Off/3/5/10-second options and cancellation | Cancel/restart and background cancellation pass touch tests | Actual delayed capture on iPhone |
| Hardware shutter | Supported iOS 18+ capture-event API routed through the shutter action | Native compilation | Volume-button delivery and timer cancellation on iPhone |
| Photo review | Paging, thumbnails, pinch/double-tap zoom, drag dismissal, sharing/information; retain the latest bracket across launches; open the system photo library | Zoom, navigation, dimensions, relaunch recovery, empty-library cancellation, PNG format/dimensions, and stored bytes/timestamps pass; library HEIF rendered correctly | Verify sharing and iCloud loading on iPhone |
| Startup and permissions | Start on appearance, observe actual session state, preserve temporary inactivity, Settings/retry actions | Native compilation; UI fixture launches successfully | Cold launch, permission approval/denial, interruption, and real-session resume |

## Remaining differences

- Photo-library browsing uses Apple's system picker. The app does not recreate the full Photos editor, favorites, or deletion flows.
- The native camera's private image processing and view-outside-frame composition are not reproduced.

## Device validation

The local host has no Xcode, and agent device access is disabled in this environment. CI runs macOS/Xcode builds and simulator tests with the real camera UI and a debug-only neutral fixture. Those tests do not prove physical capture or permission handling.

On the iPhone, check cold launch before backgrounding, first camera permission approval, returning from Control Center, background/foreground transitions, switching cameras, photo review and return, valid and invalid AEB ranges, and Photos permission denial. Check flash with AEB off in bright and dark scenes. Check each available lens, wheel dragging, focal-length cycling, focus/exposure, level/haptics, and timer/volume-button capture. Compare saved images with the preview and confirm every requested exposure appears in Photos.

The original reference photos remain local and are not included in the repository or CI artifacts.

## Aspect ratios

The viewfinder supports 4:3, 1:1, and 16:9 while retaining the measured toolbar/shutter/footer anchors. Each capture snapshots its selected aspect; JPEG processing applies the matching center crop to every exposure before saving. A 4:3 image that needs no crop retains its original bytes. Crop geometry accounts for EXIF rotation, and the encoder preserves orientation and exposure metadata. Geometry/ImageIO checks and the touch test checking square/wide output dimensions pass at `99fb9cf`. Real-camera framing still needs the device comparison.

## Focus lock

Touch and hold meters the selected point once, then displays AE/AF LOCK after observing locked focus/exposure modes and completed adjustments. A five-second failure releases metering and reports the problem. Tapping the preview refocuses; stopping the camera or switching cameras restores automatic metering. Single photos use speed prioritization while locked so image fusion does not override the locked exposure. AEB continues to use EV-bias bracket settings on the combined camera; this preserves access to its physical lenses. Confirm the locked reference and each bracket's actual exposure on an iPhone before treating this as verified capture behavior.

## Photo review

The latest saved bracket is retained in one atomically replaced binary property list in Application Support, excluded from backup. Loading and writing run off the main thread; a failed local copy does not undo a successful Photos save. The thumbnail and full-resolution review return after relaunch in the touch test. The system photo picker provides photo-only library browsing, including an empty-capture flow. The selected representation is reviewed and shared without re-encoding, with its actual file type and orientation-aware dimensions. Stored bytes/timestamps, picker cancellation, and PNG selection pass. The picker test locates the screenshot image through accessibility, checks that its bounds are visible, and taps its center because the system grid provides no XCTest hit point.

Restoration has separate loading and loaded states. Review stays disabled until loading completes, including empty-history and read-error results. Delayed-restoration touch tests use the same loader as the app. A later restoration result cannot overwrite a new capture. Capture dates remain optional: review shows Unknown date when no date was supplied or found in EXIF metadata. Metadata checks cover known and missing dates, and storage checks cover unknown dates and the original required-date file format.
