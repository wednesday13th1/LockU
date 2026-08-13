# LockU Camera release guard

Camera lifecycle has one direction:

`UI intent → CameraSessionManager → serialized controller → health validation → capture → repository transaction`

Ownership rules:

- `CameraSessionManager` owns public intent and MainActor UI state.
- `DualCameraSessionController` creates the only `AVCaptureMultiCamSession`, configures it, and serializes lifecycle work on its session queue.
- Recovery and startup/capture timeouts belong only to `DualCameraSessionController`.
- `CameraCaptureView` renders state and invokes public intent. It does not operate an AVCaptureSession.
- `MemoryRepository` and transaction types own persistence. Camera lifecycle code does not save or navigate.

Release checklist:

- Do not call `startRunning()` or `stopRunning()` from a View.
- Do not create a second MultiCam session.
- Do not bypass `DualCameraStateTransitionPolicy`.
- Do not add inputs, outputs, or higher-cost formats without checking hardware and pressure cost on physical devices.
- Do not retain `CMSampleBuffer`, `CVPixelBuffer`, or frame images outside their callback.
- Do not add lifecycle observers outside the Camera owner.
- Keep configuration, recovery, and capture callbacks generation-safe and single-flight.
- Map failures to LockU errors; never log photo data, file contents, or personal metadata.
- Light Control sends only a 0...100 percentage through `CameraSessionManager`; Views never access devices.
- Exposure bias updates stay on the existing session queue and must never restart or reconfigure the session.
- Keep auto exposure enabled. Do not turn Light Control into torch, flash, manual ISO, or shutter control.

Compatibility policy:

- Decide support from AVFoundation capability, never an iPhone model allowlist or blacklist.
- Prefer the wide camera; use the finite discovery fallback only when unavailable, then validate the complete pair with the MultiCam session's `canAdd…` APIs.
- `systemBalanced` deliberately leaves format negotiation to AVFoundation. Do not force 4K, 60 fps, or a fixed pixel subtype.
- Media-services reset must discard the old input/connection graph and rediscover devices.
- Serious thermal or pressure changes are diagnostic signals. Do not rebuild repeatedly or upgrade quality during an active session.

Physical-device result template:

```text
Device:
iOS:
MultiCam:
Selected config: systemBalanced
Front / Back device:
Hardware cost:
System pressure cost:
Startup:
Capture:
Open/Close:
Background:
Thermal:
Memory:
Result: NOT TESTED
```
