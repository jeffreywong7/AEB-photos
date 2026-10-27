# Bracket

A native iOS camera for capturing exposure brackets, designed for interiors and real estate photography. Choose three or five frames (where supported), a 0.5, 1, or 2 EV step, and a center exposure. Each exposure is saved individually to Photos as a JPEG, ready for HDR blending in your editing software. A composition grid can be toggled in the viewfinder.

## Run on iPhone

Open `Bracket/Bracket.xcodeproj` in Xcode, select the Bracket target, choose your signing team and a unique bundle identifier, and run on a physical iPhone with iOS 16 or later. Allow camera and Photos access when prompted. The simulator cannot capture photos.

Bracket availability and exposure limits depend on the active camera and device. The app uses the rear wide camera and disables capture when the selected range exceeds its supported exposure bias or when three-frame bracketing is unavailable. Five frames are offered only when the camera supports them. Flash and Live Photos are unavailable during a bracket. The app saves the source exposures; it does not merge them into an HDR image.
