# Daily Depth — TestFlight preparation

Prepared September 22, 2026. Not uploaded: Xcode currently lists only Isaac Bello (Personal Team), and the installed Xcode16.2/iOS18.2 SDK is below Apple's upload minimum. This Mac runs macOS15.1; Xcode26 requires a newer supported macOS version.

## Account and toolchain prerequisites
1. Enroll the existing Apple Account in the paid Apple Developer Program. Apple charges USD99/year or local equivalent. Complete identity, payment and legal acceptance personally: https://developer.apple.com/programs/enroll/
2. Update macOS and install a stable supported Xcode with iOS26 SDK or later. Choose it under Xcode Settings → Locations → Command Line Tools. See https://developer.apple.com/support/xcode/.
3. Refresh the Xcode account. Select the paid team for both DailyDepth and DailyDepthWidgets. The current team ID is C8DP4PG5DD; verify it after enrollment rather than replacing the bundle identifiers.

## Distribution workflow
- Keep app ID com.isaacbello.dailydepth and extension ID com.isaacbello.dailydepth.widgets. Register/enable group.com.isaacbello.dailydepth for both targets. Use the standard iOS/Widgets entitlements; do not use PersonalPreview.entitlements or PERSONAL_PREVIEW.
- Create a Daily Depth app record in App Store Connect with the existing app ID.
- Before upload, complete the privacy manifest/required-reason API audit (the app uses standard and App Group UserDefaults), privacy disclosures for optional OpenAI requests, and export-compliance answers. These are not yet submitted or claimed complete.
- Run Archive for TestFlight.command. It checks the SDK minimum, uses build number 2 for app and extension (pass a new unused build number as the first argument for subsequent uploads), builds a Release archive, and opens it in Xcode. It does not upload automatically.
- Validate the archive, then distribute to App Store Connect. ExportOptions.plist is prepared for an App Store Connect export when the paid team's distribution signing is available.
- After Apple processes the upload, use internal testing for the account holder and install through Apple's TestFlight app. External testers require Apple's beta-review flow.
- Each TestFlight build expires after90days. Upload replacement builds before expiry. TestFlight does not require public App Store release.

## Existing phone data
Do not delete the installed app. Before the first TestFlight installation, connect the phone and back up its app container. Keep the existing bundle ID and verify the same team/application identifier so an update can preserve local reflections, cards and history. The phone was unavailable during this preparation; no new data backup was taken.

## Files
ExportOptions.plist is a distribution configuration, not a signed IPA. The script cannot bypass membership, agreements or the SDK requirement. No TestFlight invitation or installable TestFlight build exists yet.
