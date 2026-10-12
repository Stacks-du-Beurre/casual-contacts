# Development TestFlight builds

Use the existing Casual Contacts app for both release and development builds.
Use a `dev/` branch for a development build. Keep the root checkout on `main`.

## Current setup

On 2026-10-11, the `Development` internal group and `Development TestFlight`
workflow were created in App Store Connect. The group has one tester. The
workflow matches branches that start with `dev/`, prepares internal-only iOS
archives, and distributes only to `Development`. It reuses the existing shared
upload variables and cancels superseded builds from the same branch.
The file rules skip a build when all changed files are Markdown or are under
`docs/`, `marketing-site/`, or `remote/`. Mixed commits with app inputs still build.
Keep `CasualContacts/`, `Packages/`, `Tools/`, and `design-assets/` eligible.
The app uses resources under `Packages/Sources/*/Resources`, not only its Xcode
project folder. Design originals are copied or converted into those resources
by tools such as `regenerate-svg.sh`; the cloud archive does not run that tool.
Commit regenerated outputs with design-source changes. Keeping design sources
eligible is conservative, but a build alone does not regenerate them.

- [Development group](https://appstoreconnect.apple.com/teams/ad0c9c03-1309-4406-9135-d5300bcc111b/apps/6763807407/testflight/groups/9dac1278-c21e-4297-8e78-fde1a76720e6)
- [Development workflow](https://appstoreconnect.apple.com/teams/ad0c9c03-1309-4406-9135-d5300bcc111b/xcode-cloud/products/603F5035-E1D3-4525-A3C0-8276542E30CA/workflows/61e35a15-0306-48d6-8559-730002601b0f)

The first cloud build and phone installation still require verification.

## Cloud configuration

The scripts do not create an Xcode Cloud workflow or a TestFlight group.
Configure these in App Store Connect before you use the push command.

1. Create an internal TestFlight group named `Development`. Add only the development testers.
2. Leave automatic distribution off when you create `Development`. Use explicit workflow post-actions for cloud builds. App Store Connect states that automatic distribution applies to Xcode uploads, not Xcode Cloud builds, and that this group setting cannot be changed later.
3. Create an Xcode Cloud workflow named exactly `Development TestFlight` for the existing Casual Contacts product and shared `CasualContacts` scheme.
4. Set its start condition to branch changes with a branch name that starts with `dev/`. Do not add a tag or pull request condition.
   Under Files and Folders, select Custom Rules → Do not start a build if only the following files and folders have changed. Add File Extension `md` from Any Folder, plus Any File from each of `/docs`, `/marketing-site`, and `/remote`.
5. Add an iOS Archive action. Select **TestFlight (Internal Testing Only)**. Do not select App Store distribution.
6. Add a TestFlight post-action that distributes only to the `Development` group.
7. Set the two existing secret environment variables: `CC_DEVELOPER_SETTINGS_UPLOAD_URL` and `CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN`. Do not put their values in Git.
8. Use Xcode Cloud build numbers. Check the product's next build number against existing uploaded builds before the first run. Do not reset it for each branch.
9. Check the other workflows. Restrict release triggers to `main` or the existing release tags. A development branch push must not start a release archive.

The development workflow uses the same bundle ID as the release workflow.
During a development archive, `ci_post_clone.sh` sets the cloud checkout to the
next patch marketing version. For example, source version `1.0.9` produces a
development archive with version `1.0.10`. This avoids the closed upload train
for an approved version. The script does not change the release version in Git.
All builds appear under the same TestFlight app.

After a release, update older development branches from `main` before you request
another build. A branch based on an older release can still select a closed train.

## Send a branch build

Create the worktree from an updated `main` that contains these scripts:

```sh
git worktree add .worktrees/dev/card-layout -b dev/card-layout main
cd .worktrees/dev/card-layout
# Make and commit the changes.
Tools/testflight-dev.sh --dry-run
Tools/testflight-dev.sh
```

The helper pushes only the current `dev/*` branch. It rejects pending changes
and creates no tags. A later push with app changes starts another build.
Pushes containing only excluded files do not start a build.
If the commit is already on the remote, the push does not start a new build.
Use Xcode Cloud's manual build action to retry that commit.

Do not use `Tools/release.sh` or `Tools/testflight.sh` for this path. Those
scripts create tags that can start the existing release workflows.

## Install on the phone

After Xcode Cloud succeeds and TestFlight finishes processing, open Casual
Contacts in TestFlight. Select the required build under Previous Builds.
Check the build number and its What to Test notes. The notes show the branch,
commit, and last commit subject. Install that build.

One app installation holds one build. A branch build uses the same saved
contacts as the release build. Test storage changes with care.

## Verify the setup

Push one `dev/*` branch. Check that only `Development TestFlight` starts.
Confirm the processed build is internal-only, belongs to `Development`, and
does not belong to a release tester group. Confirm its notes identify the
source commit. Install it from TestFlight on the phone without Tailscale.
This cloud and phone check is required before the pipeline is complete.

## References

- [Create a distribution workflow](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution)
- [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)
- [Include notes for testers](https://developer.apple.com/documentation/xcode/including-notes-for-testers-with-a-beta-release-of-your-app)
- [Set the next Xcode Cloud build number](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds)
