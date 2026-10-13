# Release automation

The release tag is the source of truth. `Tools/release.sh` commits the version, pushes main, and pushes a `v-*` tag. Xcode Cloud archives that tag. GitHub Actions runs the companion `Release App Store assets` workflow on the Mac mini runner.

## Release sequence

1. Update `AppStore/metadata/<locale>/*.txt`, including release notes.
2. Merge the app change into main.
3. Run `Tools/release.sh` (or `--build-only` for another build of the editable version).
4. The runner captures six screens for each of English, Russian, and Ukrainian on an iPhone 17 Pro Max. Dark appearance is used, matching the existing store presentation. The app target is iPhone-only; iPad compatibility mode does not require native iPad screenshots.
5. Validate all 18 images and metadata limits before changing App Store Connect. Wait for the App Store Releases archive with the same commit and tag to finish processing.
6. Replace store screenshots, upload the repository metadata, and submit that build for review. Release automatically after approval.

The pipeline does not select the newest arbitrary build. A failed archive, invalid upload, missing screenshot, or mismatched version fails the job. It does not submit development builds. Metadata uploads modify the editable version, not the live listing.

## Credentials and runner

The dedicated repository runner is `miniM4Pro-casual-contacts-release`, with label `casual-contacts-release`. Its installation is outside the repository at `~/.local/share/github-runners/casual-contacts`. The launch agent starts it when the Mac user signs in. The Mac must remain available for jobs to run; caffeinate prevents idle sleep while the upload job runs.

Encrypted repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_PRIVATE_KEY_BASE64`. Never put private keys in the repository. Apple team keys have account-wide role access; the scripts target the Casual Contacts app and its release workflow explicitly.

Dependencies are locked in Gemfile.lock and use the installed Ruby 3.3.12 through mise. Simulators, captures, derived data, and gems belong to each runner checkout. Each job creates and removes only its own simulators. PR events do not invoke this workflow.

A manual workflow dispatch defaults to uploading assets without submission. Submission requires a `v-*` tag with a matching cloud archive.

## Repository metadata

Fastlane's metadata layout supports name, subtitle, description, keywords, promotional text, release notes, support/marketing/privacy URLs, copyright, categories, and reviewer notes. Existing listing names, subtitles, and categories are preserved. The three locales contain descriptions, keywords, release notes, and URLs; edit these files for future releases. Required review contact information remains in App Store Connect unless explicitly managed.

Apple agreements, privacy declarations, age-rating responses, and reviewer correspondence are not inferred by this workflow. Review these when the app's behavior changes. Apple still performs review and approval.

## Verification

`mise exec ruby@3.3.12 -- ruby Tools/release-build.test.rb`

`bash -n Tools/generate-screenshots.sh Tools/release-store-assets.sh`

`Tools/generate-screenshots.sh --language en --appearance dark --device-id <owned-simulator-UDID> --output-dir build/captures`

The GitHub job saves the upload screenshots as an artifact for 14 days. Review the artifact and App Store Connect before changing the release workflow.
