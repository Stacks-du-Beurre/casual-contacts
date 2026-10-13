# App Store listing source

`AppStore/metadata/` is the source of truth for store copy. Do not copy and paste release text into App Store Connect.

- `en-US/`, `ru/`, and `uk/` contain names, subtitles, descriptions, keywords, promotional text, release notes, and support, marketing, and privacy URLs.
- The root files contain copyright and categories.
- `review_information/notes.txt` contains reviewer test instructions. Review contact information remains in App Store Connect.

Update release notes with each app change. Keep the camera-purpose and privacy statements consistent with the app and the published policy.

Release tags trigger screenshot generation, metadata upload, build selection, and submission. See [release automation](release-automation.md) for the workflow, credentials, and checks.

Apple agreements, age-rating responses, privacy declarations, and replies to review questions require separate review when app behavior changes. Do not infer these from store copy.
