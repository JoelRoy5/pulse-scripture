# Pulse — Scripture at the Right Moment

**Kaggle Hackathon Submission — YouVersion / Gloo AI / Wearables Category**

Pulse monitors Apple Watch biometrics and delivers a Bible verse silently to your wrist the moment it matters — not on a schedule, not via notification, but when your body signals something worth meeting with presence.

---

## The Problem

Faith apps push daily reminders at 8am regardless of what you're actually going through. They schedule the Word into your calendar instead of reading what your body is already saying.

Pulse inverts this. It listens first.

---

## What It Does

1. Apple Watch continuously writes biometric samples — HRV, heart rate, sleep stages, respiratory rate, blood oxygen, wrist temperature — to HealthKit.
2. Pulse detects a physiologically significant moment using 5 delivery triggers (see below).
3. The current biometric snapshot is classified into one of 8 emotional states using an on-device CoreML model.
4. The emotional state is sent to Gloo AI Studio, which selects the most contextually appropriate Bible verse reference.
5. The verse text is fetched from the YouVersion Platform API in the user's chosen translation.
6. The verse appears silently on the watch face — no sound, no badge, no alert. Just presence when you raise your wrist.

---

## 5 Delivery Triggers

| Priority | Trigger | Condition |
|---|---|---|
| 1 | Morning HRV | Hour 5–9, HRV < 30 ms (poor overnight recovery) |
| 2 | Late-night wakefulness | 12am–5am, watch detected sleep disruption |
| 3 | Post-workout recovery | HR was elevated, now settling (workout just ended) |
| 4 | Sustained daytime stress | HRV < 40 ms AND HR elevated ≥ 20 bpm above resting, hour 9–22 |
| 5 | 24-hour fallback | No verse delivered in the last 24 hours |

Triggers are evaluated in priority order. At most one verse is delivered per cooldown window (default 4 hours, user-adjustable to 2h or 8h).

---

## 8 Emotional States

The CoreML classifier maps biometric features to one of:

`sleepless` · `anxious` · `depleted` · `struggling` · `recovering` · `restful` · `resilient` · `unknown`

Each state routes to a different thematic verse category in Gloo AI Studio.

---

## APIs Used

| API | Role |
|---|---|
| **YouVersion Platform API** | Verse text retrieval — 2,000+ translations, authoritative reference data |
| **Gloo AI Studio API** | Faith-tuned verse selection based on classified emotional state + biometric context |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     iOS Brain (iPhone)                   │
│                                                          │
│  HealthKitManager ──► BiometricPayloadBuilder            │
│         │                      │                         │
│         ▼                      ▼                         │
│  TriggerDetector        EmotionInferenceService          │
│         │               (CoreML + rule-based stub)        │
│         └──────────────────────┐                         │
│                                ▼                         │
│                       VerseOrchestrator                  │
│                        │            │                    │
│                        ▼            ▼                    │
│               GlooAPIService  YouVersionAPIService       │
│                        │                                  │
│                        ▼                                  │
│                    VerseCache ──► WatchConnectivity       │
└─────────────────────────────────────────────────────────┘
                              │
                    WCSession (BLE)
                              │
┌─────────────────────────────────────────────────────────┐
│                  watchOS Face (Apple Watch)               │
│                                                          │
│   WatchSessionManager ──► VerseWidget (complication)    │
│                     │                                    │
│                     ▼                                    │
│           MorningView / VerseFullView                    │
└─────────────────────────────────────────────────────────┘
```

**iOS Brain** runs the full pipeline: HealthKit sampling → trigger detection → emotion classification → Gloo AI → YouVersion → verse delivery. It wakes via HealthKit background delivery and BGTaskScheduler even when the app is suspended.

**watchOS Face** receives the verse over WatchConnectivity and surfaces it as a watch face complication (WidgetKit). No network calls from the Watch — it only displays what the iPhone sends.

---

## Partner Interface: CoreML Emotion Classifier

The current build ships a rule-based stub (`EmotionInferenceService.swift`). The production CoreML model is a parallel workstream.

**To integrate the partner model:**

1. Add `PulseEmotionClassifier.mlmodel` to `Pulse/Pulse/ML/`
2. Replace the stub body in `EmotionInferenceService.swift` with the CoreML call (commented template is already in place).

**Input feature contract** (`BiometricFeatures` struct):

| Feature | Type | Description |
|---|---|---|
| `hrv_sdnn` | Double | HRV SDNN in milliseconds |
| `hrv_7day_slope` | Double | 7-day HRV trend slope |
| `hr_delta_from_resting` | Double | Current HR minus resting HR (bpm) |
| `sleep_efficiency` | Double | 0.0–1.0 |
| `deep_sleep_pct` | Double | 0.0–1.0 |
| `rem_pct` | Double | 0.0–1.0 |
| `awakening_count` | Double | Number of awakenings last night |
| `late_night_wakefulness` | Double | 1.0 = woke between 12am–5am |
| `respiratory_rate` | Double | Breaths per minute |
| `blood_oxygen` | Double | SpO2 (0.0–1.0) |
| `wrist_temp_delta` | Double | Delta from baseline in °C |
| `time_of_day_sin` | Double | Circular time encoding (sin) |
| `time_of_day_cos` | Double | Circular time encoding (cos) |

**Output:** `EmotionClassification` with `.state: EmotionalState`, `.confidence: Double`, `.probabilities: [String: Double]`

---

## Tech Stack

| Layer | Technology |
|---|---|
| iOS app | Swift 5.9, SwiftUI, iOS 17+ |
| watchOS app | Swift 5.9, SwiftUI, watchOS 10+ |
| Watch complication | WidgetKit |
| Biometrics | HealthKit (background delivery) |
| Background refresh | BGTaskScheduler (`com.pulse.refresh`) |
| Watch communication | WatchConnectivity (WCSession) |
| On-device ML | CoreML (stub; real model from partner) |
| Persistence | UserDefaults (via App Group) |
| Verse delivery | Gloo AI Studio API + YouVersion Platform API |

---

## Setup

### Prerequisites
- Xcode 15.2 or later
- iOS 17+ iPhone with paired Apple Watch (Series 4+)
- Apple Developer account (for HealthKit background delivery — requires real device)

### Steps

1. Clone this repo:
   ```bash
   git clone https://github.com/JoelRoy5/pulse-scripture
   cd pulse-scripture
   ```

2. Open the Xcode project:
   ```bash
   open Pulse/Pulse.xcodeproj
   ```

3. Set your Team in Signing & Capabilities for both the `Pulse` and `PulseWatch Watch App` targets.

4. Create `Pulse/Pulse/Secrets.swift` (this file is gitignored — do not commit it):
   ```swift
   enum Secrets {
       static let glooAPIKey    = "YOUR_GLOO_API_KEY"
       static let youVersionAPIKey = "YOUR_YOUVERSION_API_KEY"
   }
   ```

5. Set the App Group on both targets:
   - In Signing & Capabilities, add `group.com.YOURTEAM.pulse` to both `Pulse` and `PulseWatch Watch App`.
   - Replace `YOURTEAM` with your actual Apple Developer team identifier.
   - The `VerseCache` and `WatchSessionManager` use `UserDefaults(suiteName:)` with this group.

6. Add the Widget Extension target (required for watch face complication):
   - File → New → Target → Widget Extension, name it `PulseWidget`.
   - Replace the generated files with the ones in `Pulse/PulseWatch Watch App/Widget/`.
   - Add the App Group entitlement to the Widget target as well.

7. Add the BGTaskScheduler plist key:
   - In the `Pulse` target's Info tab, add `BGTaskSchedulerPermittedIdentifiers` as an Array with one item: `com.pulse.refresh`.

8. Run on a real device (HealthKit background delivery does not work in Simulator).

---

## Screenshots

_Screenshots to be added after TestFlight build is validated._

| Screen | Description |
|---|---|
| Watch face | Verse complication on Modular or Infograph face |
| Morning view | Full verse display on Watch after HRV trigger |
| iPhone settings | Cooldown, translation, and notification preferences |
| iPhone onboarding | HealthKit permission request flow |

---

## Submission Checklist

- [x] iOS app builds and runs on device
- [x] HealthKit background delivery configured
- [x] Gloo AI Studio integration complete
- [x] YouVersion Platform API integration complete
- [x] WatchConnectivity verse push implemented
- [x] WidgetKit complication wired
- [x] 5 delivery triggers implemented and tested
- [x] 8 emotional state classifier (stub; CoreML drop-in ready)
- [x] README and setup instructions
- [ ] TestFlight public link (see `docs/TESTFLIGHT.md`)
- [ ] Kaggle notebook / writeup
