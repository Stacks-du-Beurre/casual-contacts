# Privacy Policy

**Casual Contacts** &mdash; Effective October 13, 2026

Casual Contacts is a local-first iOS app for remembering people you've just met. This page explains, plainly, what the app does with your data.

## The short version

- Everything you enter stays on your device.
- There is no account, no server, no analytics, and no advertising.
- We don't track you and we don't share your data with anyone.

## What the app stores

When you create a record, the app saves the details you provide &mdash; typically a name, an association, and any notes &mdash; to a private database on your device. You can also attach a photo and the place you met, both of which are optional.

The app additionally records ambient context at the moment of capture (the date and time, a derived time-of-day label, and a moon phase) so it can render the visual "card" associated with the record. None of this leaves your device.

## Permissions

- **Location (When In Use)** &mdash; used only when you choose to tag where you met someone. Coordinates are stored locally with the record. Decline this permission and location simply isn't recorded.
- **Motion & Fitness** &mdash; used to drive subtle parallax and tilt animations on the visual cards. Motion data is read in-memory and never stored or transmitted.
- **Camera & Photo Library** &mdash; used when you choose to attach a photo to a record or enable optional camera perspective. Photos are saved to the app's private storage on your device.

You can revoke any of these at any time in iOS Settings.

## Face data and TrueDepth

### Information processed

When you enable camera mode for the optional 3D scene, Apple ARKit and the TrueDepth/front camera process camera frames and a tracked face anchor. Casual Contacts reads the face transform, left and right eye transforms, camera transform, tracking status, and frame timestamps to calculate the midpoint of your eyes and its position and distance relative to the screen. The app does not read facial-expression blend shapes, face mesh vertices, gaze targets, or Face ID identity data.

### Purpose and consent

This information is used only to animate the perspective of the layered contact cards. It is not used for identification, authentication, profiling, advertising, or analytics. Camera mode is optional and off by default. You can use gyro motion without camera access. The app explains camera use before requesting permission. If you decline the system permission request, cards use gyro motion. You can turn camera mode off in 3D scene or revoke Camera access in iOS Settings.

### Sharing and disclosure

Camera frames and face data are not uploaded, transmitted, sold, or shared with any third party. No third-party service receives this information. Apple ARKit processes the data locally on the device.

### Storage, retention, and deletion

Camera frames and derived face/eye positions exist only in volatile memory on your device during the active tracking session. They are not written to the contact database, files, photos, backups, or logs. The app retains the latest derived viewpoint and a short motion-orientation buffer to smooth animation and continue with gyro when the face leaves view. Tracking stops and this session data is cleared when you turn off camera mode or the 3D scene, leave the enabled card views, or the app becomes inactive. No face data is retained between sessions; there is no stored face data to delete. Photos you deliberately attach to a contact are separate from this feature and remain locally stored until you delete them or the record.

## What we don't do

- We do not receive or transmit your personal data. The app processes data locally as described above.
- We do not use third-party analytics, crash reporting, or advertising SDKs.
- We do not track you across other apps or websites.
- We do not sell or share your data, because we don't have it.

## Children

Casual Contacts is not directed to children under 13 and does not knowingly collect data from anyone, of any age, on a server we control &mdash; because we don't operate one.

## Changes to this policy

If this policy changes in a material way, the updated version will be posted at this URL with a revised effective date.

## Contact

Questions about this policy? Email [hello@therealadammork.com](mailto:hello@therealadammork.com).

---

&copy; 2026 Casual Contacts. [casualcontacts.app](/)
