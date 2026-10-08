## 0.1.1-dev.5

* Raised the default face-similarity match threshold from 0.70 to 0.75.
* Added progressive live distance guidance with an animated arrow and proximity bar in the demo.
* Removed face-guide shapes from the recognition and liveness camera screens.

## 0.1.1-dev.4

* Rebuilt the demo with an embedded camera experience for registration and continuous verification.
* Added native Android NV21 camera-frame APIs for immediate stream-based enrollment, recognition, and liveness without taking photos.
* Added locally stored person names, live recognition/liveness overlays, and a dedicated recognition success screen.
* Refreshed the demonstration UI with a production-style home screen and guided face capture.

## 0.1.1-dev.3

* Fixed the demo enrollment flow so face actions remain disabled until activation and model installation finish.
* Added explicit enrollment state, clearer capture feedback, and guarded recognition/liveness actions until a template exists.
* Normalized Android camera JPEG orientation from EXIF metadata before face detection.

## 0.1.1-dev.2

* Added app-bound seven-day trials that begin on first activation.
* Added private CLI tooling to create, list, and disable trial or lifetime keys.
* Added a direct-launch Android demonstration build and public download documentation.

## 0.1.1-dev.1

* Renamed the package and public API to `mml_face_sdk` and `MmlFaceSdk`.
* Changed commercial licensing to lifetime, app-bound keys reusable across installations.
* Removed all biometric model weights from the publishable package.
* Added one-time encrypted private model-pack delivery during activation.
* Added app-private native model installation with tensor-shape validation.

## 0.1.0

* Initial pre-release Flutter API for enrollment, recognition, and passive-liveness verification.
* Native Android ML Kit/TFLite and iOS Vision/TensorFlow Lite engines.
* Offline Ed25519 seven-day trial licences and Cloudflare Worker activation backend.
* Example app, automated compatibility/licensing tests, security and release documentation.
