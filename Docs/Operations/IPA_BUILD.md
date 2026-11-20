# IPA build, signing and release handbook

## Mac prerequisite

Xcode command-line tools and iOS SDK, XcodeGen (`brew install xcodegen`). Xcode project derives from `project.yml`. The source baseline `Gomoku` swift shell can compile only on macOS with iOS SDK; Linux CMake success is not proof of iOS build success.

```sh
xcodegen generate --spec project.yml
xcodebuild -project Gomoku.xcodeproj -scheme Gomoku -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Gomoku.xcodeproj -scheme Gomoku -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

In **Actions → Gomoku CI → Run workflow**, enter the reviewed 40-character commit SHA in `expected_sha`. After core checks and simulator tests pass, CI packages the device build as an **unsigned** developer-only IPA. Leave the input blank to run CI alone. This is not a signed installable IPA on standard stock iOS. Any use of sideloading tools is outside of this package's claims.

## Signed IPA

Requires verified Apple team ID, certificate, provisioning profile with exact bundle `studio.zeo.gomoku`, export method and entitlement set. Keep credentials in protected secrets, not source. Work should configure signing only if actual secure credentials/permissions are available and owner has authorized release. Distinct app icon and native Info.plist privacy declarations must match actual capabilities (Bluetooth, Files where needed).

Actual post-build validation: `codesign -dv`, `plutil`, valid embedded profile, `unzip -t`, SHA256, installation on a device where permitted, launch/game smoke, crash-free run, source/model version visible. Record real results; do not claim a signing success from a successfully zipped unsigned `.app`.
