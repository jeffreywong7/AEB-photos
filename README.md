# Bracket

A native iOS camera for capturing exposure brackets, designed for interiors and real estate photography. Choose three or five frames (where supported), a 0.5, 1, or 2 EV step, and a center exposure. Each exposure is saved individually to Photos as a JPEG, ready for HDR blending in your editing software. A composition grid can be toggled in the viewfinder.

## Run on iPhone

Open `Bracket/Bracket.xcodeproj` in Xcode, select the Bracket target, choose your signing team and a unique bundle identifier, and run on a physical iPhone with iOS 16 or later. Allow camera and Photos access when prompted. The simulator cannot capture photos.

## Camera controls

- Tap **AEB** or the top chevron to show frame count, EV spacing, center exposure, and the grid toggle. Swipe up on the viewfinder to open these controls and down to close them.
- Tap the viewfinder to set focus and exposure. Drag the sun up or down to change the center exposure. Pinch to zoom, or tap a zoom preset. Touch and hold a zoom button, or drag it horizontally, to open the zoom wheel. Tap the selected **1×** main-camera button to cycle through 24, 28, and 35 mm framing, using crops relative to the 24 mm main camera on the reference iPhone 15 Pro.
- Tap the white shutter to capture a bracket. Each exposure saves individually to Photos. Turn **AEB** off in the drawer to take a single photo.
- Tap the flash icon to choose **Auto**, **On**, or **Off** for single photos. While AEB is enabled, the menu offers explicitly labeled options that turn AEB off before enabling flash.
- Tap the bottom-left thumbnail to review the last saved bracket. Swipe between its exposures, then tap **Done** to return to the camera.
- Tap the bottom-right camera button to switch between the front and rear cameras. Lens stops, including 0.5×, depend on the iPhone and AEB support.

Bracket availability and exposure limits depend on the active camera and device. If the combined rear camera does not support AEB, the app uses the wide camera. Capture is disabled when the selected range exceeds its supported exposure bias or three-frame bracketing is unavailable. Five frames are offered only when the camera supports them. Apple’s bracket-capture API does not support flash or Live Photos. Flash works for single photos when the selected camera supports it. The app saves the source exposures; it does not merge them into an HDR image. Photo review contains only the last bracket saved during the current app session.

## Validate on a device

Build and run on an iPhone to verify the camera layout, focus, zoom, camera switching, and saving a complete bracket. Check both supported and unsupported exposure ranges, Photos permission denial, and returning from the background. Compare the screen with the built-in Camera app on the same iPhone. Run `scripts/verify-ios.sh` on macOS to build for iOS Simulator without signing. The same command runs in the iOS build workflow on pull requests. This checks compilation; physical camera capture and the visual comparison still need an iPhone.
