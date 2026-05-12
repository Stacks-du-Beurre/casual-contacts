# Developer Settings Export

Developer Settings can upload the current visual/motion tuning snapshot to the
remote collector at:

```text
https://casualcontacts.app/api/developer-settings
```

The upload row only appears when both build-time Info.plist values are present:

- `CCDeveloperSettingsUploadURL`
- `CCDeveloperSettingsUploadToken`

Open-source checkouts build without those values. The decrypted contributor
file is ignored at `CasualContacts/Config/DeveloperSettingsUpload.xcconfig`.

## Contributor Secret Setup

The repo is initialized for `git-secret`; the actual token file should be added
after a contributor with the production token and a GPG identity is available:

```bash
git secret tell <contributor-gpg-id>
cp CasualContacts/Config/DeveloperSettingsUpload.xcconfig.example \
  CasualContacts/Config/DeveloperSettingsUpload.xcconfig
$EDITOR CasualContacts/Config/DeveloperSettingsUpload.xcconfig
git secret add CasualContacts/Config/DeveloperSettingsUpload.xcconfig
git secret hide
git add .gitsecret CasualContacts/Config/DeveloperSettingsUpload.xcconfig.secret
```

Authorized contributors reveal the file before building:

```bash
git secret reveal
xcodebuild build \
  -scheme CasualContacts \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Remote Setup

The Worker lives in `remote/developer-settings-worker/` and stores accepted
payloads in R2 under `developer-settings/*.json`.

```bash
cd remote/developer-settings-worker
wrangler r2 bucket create casual-contacts-developer-settings
wrangler secret put DEVELOPER_SETTINGS_UPLOAD_TOKEN
wrangler deploy
```

The Worker route is configured for `casualcontacts.app/api/developer-settings`.

## Ingesting A Submission

Download or export one R2 JSON object, then regenerate defaults:

```bash
Tools/developer-settings-ingest.mjs /path/to/submission.json
cd Packages
swift test
```

The tool validates schema version `1` and rewrites:

- `Packages/Sources/CoreModels/Tuning/CoreDeveloperSettingsDefaults.swift`
- `Packages/Sources/Visuals/DeveloperSettings/VisualDeveloperSettingsDefaults.swift`

Review the generated diff before committing because those values become the new
shipping defaults.
