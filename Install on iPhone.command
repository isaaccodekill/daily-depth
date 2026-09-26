#!/bin/zsh
set -e
cd "${0:A:h}"
xcodebuild -project DailyDepth.xcodeproj -scheme DailyDepth -sdk iphoneos \
  -destination 'id=00008140-001525303C30801C' -configuration Release \
  -derivedDataPath ../../work/PersonalPhoneInstall DEVELOPMENT_TEAM=C8DP4PG5DD \
  CODE_SIGN_ENTITLEMENTS=DailyDepth/PersonalPreview.entitlements \
  OTHER_SWIFT_FLAGS=-DPERSONAL_PREVIEW \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
xcrun devicectl device install app --device 99178216-1A11-4E80-A9AC-5B0F78F62E9C \
  '../../work/PersonalPhoneInstall/Build/Products/Release-iphoneos/Daily Depth.app'
xcrun devicectl device process launch --device 99178216-1A11-4E80-A9AC-5B0F78F62E9C com.isaacbello.dailydepth
