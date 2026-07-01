# TestFlight Distribution Notes

This document covers the manual Xcode steps required before archiving, then the Archive → TestFlight workflow.

---

## Prerequisites

- **Apple Developer account** (paid, $99/year) — required for HealthKit background delivery entitlement and TestFlight distribution.
- **Real iPhone** running iOS 17+ paired with Apple Watch Series 4+ running watchOS 10+.
- **Xcode 15.2+** on macOS Sonoma or later.
- **API keys** in `Pulse/Pulse/Secrets.swift` (gitignored — never commit this file):
  ```swift
  enum Secrets {
      static let glooAPIKey       = "YOUR_GLOO_API_KEY"
      static let youVersionAPIKey = "YOUR_YOUVERSION_API_KEY"
  }
  ```

---

## Manual Xcode Steps (one-time setup)

These steps cannot be automated by code — they require manual interaction with Xcode project settings.

### 1. App Group Entitlement

The `VerseCache` and `WatchSessionManager` share data via `UserDefaults(suiteName: "group.com.YOURTEAM.pulse")`. The App Group must be registered and applied to all three targets that share data.

**Steps:**
1. In Xcode, select the `Pulse` project in the navigator.
2. Select the `Pulse` target → Signing & Capabilities.
3. Click `+ Capability` → App Groups.
4. Add `group.com.YOURTEAM.pulse` (replace `YOURTEAM` with your Apple Developer Team ID — find it at developer.apple.com/account under Membership).
5. Repeat for the `PulseWatch Watch App` target.
6. If you add a Widget Extension target (see step 2 below), add the App Group there too.

### 2. Widget Extension Target

The watch face complication lives in `Pulse/PulseWatch Watch App/Widget/`. These source files need a Widget Extension target to compile.

**Steps:**
1. File → New → Target → Widget Extension.
2. Name: `PulseWidget`. Language: Swift. Include Live Activity: No.
3. Xcode generates placeholder files — delete them.
4. Add the following existing files to the `PulseWidget` target (check the target membership box in the File Inspector):
   - `Pulse/PulseWatch Watch App/Widget/VerseEntry.swift`
   - `Pulse/PulseWatch Watch App/Widget/VerseTimelineProvider.swift`
   - `Pulse/PulseWatch Watch App/Widget/VerseWidget.swift`
   - `Pulse/PulseWatch Watch App/Widget/VerseWidgetBundle.swift`
   - `Pulse/PulseWatch Watch App/SharedVerse.swift`
5. Add the `App Groups` capability to the `PulseWidget` target with the same group ID.

### 3. BGTaskScheduler Plist Key

Background refresh is registered under the identifier `com.pulse.refresh`. iOS requires this to be declared in the app's Info plist or Xcode Info tab.

**Steps:**
1. Select the `Pulse` target → Info tab.
2. Add a new key: `BGTaskSchedulerPermittedIdentifiers` (type: Array).
3. Add one item (type: String): `com.pulse.refresh`.

This is equivalent to adding the following to `Info.plist`:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.pulse.refresh</string>
</array>
```

---

## Archive and Upload to TestFlight

Once the manual steps above are complete and the app builds cleanly on a real device:

1. **Select a real device** as the run destination (or "Any iOS Device (arm64)").

2. **Product → Archive**
   - Wait for the archive to complete. The Organizer window opens automatically.

3. **Distribute App**
   - In the Organizer, select the archive and click "Distribute App".
   - Choose: **TestFlight & App Store**.
   - Follow the wizard — Xcode uploads the build to App Store Connect.

4. **Process in App Store Connect**
   - Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com).
   - My Apps → Pulse → TestFlight.
   - Wait for the build to finish processing (typically 5–15 minutes).

5. **Create a Public Link**
   - TestFlight → your processed build → Open Testing.
   - Enable "Public Link" — App Store Connect generates a `testflight.apple.com/join/...` URL.
   - Copy this link for the Kaggle submission form.

6. **Internal vs External Testing**
   - For hackathon judges, a Public Link (no invite required) is the simplest option.
   - Internal testing requires adding testers by Apple ID; external testing requires Beta App Review.

---

## Build Numbers

Increment `CFBundleVersion` in the `Pulse` target before each TestFlight upload — App Store Connect rejects duplicate build numbers.

Convention used for this submission:
- Version: `1.0` (`CFBundleShortVersionString`)
- Build: `1`, `2`, `3`… each archive

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Missing App Group entitlement" at launch | Verify the group ID matches exactly (case-sensitive) in both targets and in `VerseCache.swift` / `WatchSessionManager.swift` |
| HealthKit background delivery not firing on device | Confirm `com.apple.developer.healthkit.background-delivery` entitlement is set to `true` in `Pulse.entitlements` |
| Widget not appearing on watch face | Ensure `PulseWidget` target is included in the watchOS app's embed step |
| Secrets.swift missing compile error | Create `Pulse/Pulse/Secrets.swift` with the `Secrets` enum (see Prerequisites above) |
| BGTaskScheduler task not registering | Confirm `BGTaskSchedulerPermittedIdentifiers` contains `com.pulse.refresh` in the Info plist |
