# Native Camera reference

The visual reference is the user's iPhone 15 Pro screenshots, supplied at 923×2000 pixels. They show the newer Camera design with a centered toolbar, separate shutter and mode rows, circular utility buttons, a glass PHOTO selection, and lens controls inside the viewfinder. Photo capture and AEB remain the app's scope.

## Behavior confirmed with Apple

- Camera supports pinch zoom and holding the lens selector while dragging horizontally. [Camera basics](https://support.apple.com/en-ie/guide/iphone/iph263472f78/27/ios/27).
- On iPhone 15 Pro, tapping the main-camera selector cycles the enabled 24, 28, and 35 mm choices. [Customize the Main camera lens](https://support.apple.com/guide/iphone/customize-the-main-camera-lens-iph72395b28f/27/ios/27).
- Camera tools include a 3/5/10-second timer, exposure adjustment, aspect ratios, and grid/level settings. Holding the focus area locks focus and exposure. The newer toolbar can be customized. [Camera tools](https://support.apple.com/en-ae/guide/iphone/iph3dc593597/27/ios/27).
- The newer camera layout and translucent controls are part of Apple's Liquid Glass redesign. [Apple's design announcement](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/).
- Apple's bracket-capture API does not support flash or Live Photos. Single photos can use flash; AEB must keep it off. [Bracket capture settings](https://developer.apple.com/documentation/avfoundation/avcapturephotobracketsettings).

Apple's capture-controls session describes handling physical-button releases through `onCameraCaptureEvent`, and disabling it when capture cannot be handled. The app routes that event through the same shutter action, including timer cancellation. [Capture controls](https://developer.apple.com/videos/play/wwdc2025/253/).

## Measured layout

These are measurements from the supplied screenshots, not dimensions published by Apple. At 393×852 points, the 4:3 frame starts at y=118 and ends at y=642. The toolbar center is near y=82, the shutter near y=698, and the thumbnail/PHOTO/camera-switch row near y=794. The selected main-camera zoom stop is centered horizontally. `tests/CameraLayout/main.swift` checks these anchors and checks that compact iPhone layouts keep the controls separate from the captured frame.

The original screenshots remain local reference material and are not included in this repository or uploaded to CI. Simulator snapshots use a neutral fixture scene and the actual SwiftUI camera screen. Those snapshots verify UI layout; they do not verify physical camera behavior or Apple's image-processing pipeline.
