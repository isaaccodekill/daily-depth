#!/bin/zsh
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
sdk_version=$(xcrun --sdk iphoneos --show-sdk-version)
if (( ${sdk_version%%.*} < 26 )); then
  print -u2 "TestFlight requires iOS SDK 26 or later. Select a supported Xcode in Xcode > Settings > Locations > Command Line Tools. Current SDK: $sdk_version"
  exit 1
fi
build_number="${1:-2}"
archive_path="$PWD/TestFlight/Archives/DailyDepth-$build_number.xcarchive"
xcodebuild -project DailyDepth.xcodeproj -scheme DailyDepth -configuration Release -destination 'generic/platform=iOS' -archivePath "$archive_path" -derivedDataPath "${TMPDIR:-/tmp}/DailyDepth-TestFlight" CURRENT_PROJECT_VERSION="$build_number" -allowProvisioningUpdates archive
print "Archive created: $archive_path"
print "Open in Xcode Organizer, Validate App, then Distribute App > App Store Connect > TestFlight."
open "$archive_path"
