# Pulse — Design Spec
*Scripture in New Frontiers Hackathon · YouVersion + Gloo AI · 2026-06-30*

---

## Concept

Pulse is a watchOS/iOS app that monitors biometric signals continuously and delivers a scripture verse at the exact physiological moment a person needs it — not on a schedule, not randomly, but when the body says something is happening.

A person wakes at 3am. Their Apple Watch has been tracking HRV, heart rate, and sleep stages all night. Pulse detects the wakefulness spike, classifies the emotional state using a custom on-device ML model, and quietly updates the watch face with a verse. No sound. No notification. Just presence when they raise their wrist.

The goal is not another Bible app. It is Scripture present in a human moment that no app has ever reached before.

---

## Required APIs

Both APIs are required by the competition and used as follows:

- **Gloo AI Studio API** — receives classified emotional state + biometric context, returns the most resonant scripture reference and a 1–2 sentence faith-tuned reflection. Gloo handles the spiritual intelligence layer: which verse, and how to frame it.
- **YouVersion Platform API** — receives the scripture reference returned by Gloo, returns verse text in the user's preferred translation and language (2,000+ options).

---

## Architecture

### Overview

```
Apple Watch sensors
    → HealthKit (shared iOS/watchOS store)
        → HealthKitManager (iOS)
            → BiometricPayloadBuilder
                → CoreML Model (on-device emotion inference)
                    → TriggerDetector (should we fetch a verse right now?)
                        → GlooAPIService (which verse + reflection)
                            → YouVersionAPIService (verse text)
                                → VerseCache (local storage)
                                    → WatchSessionManager
                                        → watchOS: complication + full view
```

### Two-model Intelligence Layer

The emotional inference uses two complementary systems:

**Custom CoreML Model (on-device)**
- Input: biometric feature vector (13 features — see Data Layer)
- Output: probability distribution across 8 emotional states
- Runs entirely on-device — no health data leaves the phone at this stage
- Fast, private, works offline
- Trained in Python on public physiological datasets + clinically-derived synthetic data, exported to CoreML format

**Gloo AI Studio API (cloud)**
- Input: classified emotional state + lightly rounded biometric context (no user identity) + user preferences
- Output: scripture reference + spiritual theme + 1-sentence reflection
- Faith-tuned — understands ministry context, safe, appropriate
- Receives anonymized context only — no account link, no persistent user ID, values rounded to reduce precision

This separation is both a privacy win and an architectural win: the CoreML model does the private classification on-device; Gloo uses the classified state plus coarse context to select the right verse and frame it well.

---

## Data Layer (V1 Scope)

### HealthKit Signals Read by iOS App

| Signal | HealthKit Identifier | Notes |
|---|---|---|
| HRV SDNN | `heartRateVariabilitySDNN` | Primary stress/recovery signal. Measured overnight. |
| Heart Rate | `heartRate` | Real-time. Watch writes continuously. |
| Resting Heart Rate | `restingHeartRate` | Apple-computed daily baseline. |
| Sleep Analysis | `sleepAnalysis` | Stages: Deep, REM, Core, Awake. Requires Series 4+ / watchOS 9+. |
| Respiratory Rate | `respiratoryRate` | Elevated during anxiety; measured passively during sleep. |
| Blood Oxygen | `oxygenSaturation` | Spot checks; secondary signal. |
| Wrist Temperature | `appleSleepingWristTemperature` | Series 8+ / Ultra only; graceful fallback if unavailable. |

### How iOS Reads Watch Data

Apple Watch writes all sensor data into the shared HealthKit database. The iOS app reads from that database directly — no separate Watch API required. The watchOS target exists only to display output (complications, full-screen view).

### Feature Vector (input to CoreML model)

```swift
struct BiometricFeatures {
    // HRV
    var hrv_sdnn: Double              // ms, current reading
    var hrv_7day_slope: Double        // normalized trend (-1 declining → +1 improving)

    // Heart rate
    var hr_delta_from_resting: Double // current HR minus resting HR (bpm)

    // Sleep
    var sleep_efficiency: Double      // 0.0–1.0
    var deep_sleep_pct: Double        // 0.0–1.0
    var rem_pct: Double               // 0.0–1.0
    var awakening_count: Double       // count of wake events
    var late_night_wakefulness: Double // 1.0 if wake between 1am–5am, else 0.0

    // Respiratory + oxygen
    var respiratory_rate: Double      // breaths/min
    var blood_oxygen: Double          // percentage (0–100)

    // Temperature
    var wrist_temp_delta: Double      // °C deviation from personal baseline

    // Time context (cyclical encoding avoids midnight discontinuity)
    var time_of_day_sin: Double       // sin(2π * hour / 24)
    var time_of_day_cos: Double       // cos(2π * hour / 24)
}
```

### Emotional State Classes

The CoreML model outputs probabilities across 8 states:

| State | Primary Biometric Signature |
|---|---|
| `sleepless` | Late-night wakefulness, elevated HR, low HRV |
| `anxious` | Elevated HR at rest (no workout), low HRV, normal sleep |
| `depleted` | Low HRV, poor sleep quality, low energy |
| `struggling` | HRV declining trend over 5+ days, sustained stress |
| `recovering` | Post-workout, HR returning to baseline, improving HRV |
| `restful` | Low HR, good HRV, morning or Sunday pattern |
| `resilient` | Good HRV despite recent stress signals (bouncing back) |
| `unknown` | Insufficient or ambiguous data |

---

## ML Model: Training Plan

### Goal
Train a multiclass classifier that maps a biometric feature vector to one of the 8 emotional states above. Export to CoreML for on-device inference.

### Training Data Sources

1. **WESAD dataset** (public, free) — Wearable Stress and Affect Detection. Physiological signals (respiration, HR, skin conductance) labeled with stress / amusement / neutral. Note: WESAD signals don't map perfectly to Apple Watch outputs (no SDNN, no sleep stages) — feature engineering bridges this gap but introduces approximation.
2. **Clinically-derived synthetic data** (primary source for sleep/HRV states) — HRV and HR correlations with emotional states are well-established in the literature (Thayer & Lane, Kim et al., Shaffer & Ginsberg). Generate labeled biometric profiles for each state using published clinical ranges as priors. This is the more reliable source for our specific feature set.
3. **Kaggle notebook** documents both sources, the feature engineering pipeline, model training, evaluation (confusion matrix, per-class F1), and CoreML export.

### Model Architecture
Random Forest (100 estimators, max_depth=8). Handles missing values (not all signals available on all devices), interpretable for the writeup, performs well on small tabular datasets. If evaluation shows underfitting, switch to Gradient Boosting.

### Export
```python
import coremltools as ct
coreml_model = ct.converters.sklearn.convert(rf_model, feature_names, 'emotionalState')
coreml_model.save('PulseEmotionClassifier.mlmodel')
```

The `.mlmodel` file is bundled with the iOS app. No network call required for inference.

---

## Delivery Logic

### Trigger Moments (when Pulse calls Gloo)

The `TriggerDetector` watches for these events and fires a verse pipeline when one occurs:

| Trigger | Condition |
|---|---|
| **Morning HRV** | New HRV reading arrives after sleep session ends |
| **3am wakefulness** | HR delta > 15bpm with no movement, between 1am–5am |
| **Post-workout** | Heart rate returning to baseline after an active workout session |
| **Sustained daytime stress** | HR delta > 20bpm for 45+ continuous minutes, no workout active |
| **24-hour fallback** | No verse delivered in the past 24 hours |

Extensible — multi-day stress trend, post-illness recovery, and others added post-competition.

### Smart Cadence (no hard cap, no spam)

```
After each delivery:
  → Enter cooldown (minimum 2 hours)
  → Cooldown extends if user dismissed without tapping (low engagement)
  → Cooldown shortens if user tapped through to full view (high engagement)

Nighttime (midnight–6am):
  → Silent delivery only — complication updates but no haptic
  → Only sleepless / 3am triggers fire in this window

Per-day behavior:
  → No fixed cap, but triggers require meaningful biometric threshold
  → Gloo API calls rate-limited to avoid cost runaway
```

### What Gloo AI Receives

```json
{
  "emotional_state": "sleepless",
  "state_confidence": 0.89,
  "supporting_signals": {
    "hrv_sdnn_ms": 17.0,
    "hr_delta_bpm": 22,
    "late_night_wake": true,
    "sleep_efficiency": 0.61,
    "hrv_trend": "declining"
  },
  "time_context": {
    "time_of_day": "03:22",
    "day_of_week": "Tuesday"
  },
  "user_preferences": {
    "translation": "NIV",
    "language": "en"
  }
}
```

Raw biometric values are included at this stage (lightly rounded) because Gloo AI can use them to nuance the reflection — but no user identity is ever sent.

### What Gloo AI Returns

```json
{
  "scripture_theme": "peace_in_sleeplessness",
  "verse_reference": "PSA.4.8",
  "verse_display_label": "Psalm 4:8",
  "reflection": "Your body is restless tonight. You are still held."
}
```

### YouVersion Fetch

```
GET /bible/verse/{version_id}/{usfm}
GET /bible/verse/111/PSA.4.8    ← NIV (version 111)
```

Response provides verse text + version name. Cached locally in `VerseCache`.

---

## Watch Display Layer

### Three Surfaces

**1. Complication (primary, passive)**
WidgetKit complication in Modular Large and Graphic Rectangular families. Shows verse text. Updates silently when a new verse arrives — no haptic, no sound, no banner. The verse is just there the next time they raise their wrist.

**2. Full-screen verse view (on tap)**
Tapping the complication opens a full-screen SwiftUI view with:
- Verse text (large, readable)
- Reference label
- Gloo reflection (1–2 sentences, smaller)
- Subtle ambient background (no busy design)

**3. Morning view (proactive)**
Detected from sleep analysis end time. On the first wrist raise after waking, a morning-specific verse surfaces with a gentle haptic. The only time Pulse initiates a haptic.

---

## Privacy Model

- **CoreML runs fully on-device** — biometric features never leave the phone during inference
- **Gloo receives anonymized context** — no user identity, no account link, no persistent ID
- **YouVersion receives only** a verse reference and version preference — no health data
- **Nothing stored remotely** — all verses cached in UserDefaults, purged after 30 days
- **HealthKit permissions requested one category at a time** with plain-language explanation of why each is needed
- **V1 intentionally excludes** reproductive, nutrition, and mental health data — these require a separate opt-in flow with additional privacy explanation, planned post-competition

---

## Project Structure

```
pulse-scripture/
├── Pulse/                           # iOS target
│   ├── Health/
│   │   ├── HealthKitManager.swift   # authorization, background delivery, queries
│   │   ├── TriggerDetector.swift    # monitors for delivery moments
│   │   └── BiometricPayloadBuilder.swift
│   ├── ML/
│   │   ├── PulseEmotionClassifier.mlmodel  # bundled CoreML model
│   │   └── EmotionInferenceService.swift   # wraps CoreML prediction
│   ├── API/
│   │   ├── GlooAPIService.swift
│   │   └── YouVersionAPIService.swift
│   ├── Models/
│   │   ├── BiometricFeatures.swift
│   │   ├── EmotionalState.swift
│   │   ├── GlooResponse.swift
│   │   └── ScriptureVerse.swift
│   ├── Storage/
│   │   └── VerseCache.swift
│   ├── Connectivity/
│   │   └── WatchSessionManager.swift
│   └── Views/
│       ├── OnboardingView.swift
│       ├── PermissionsView.swift
│       └── SettingsView.swift
│
├── PulseWatch/                      # watchOS target
│   ├── Complications/
│   │   └── VerseWidget.swift        # WidgetKit
│   └── Views/
│       ├── VerseFullView.swift
│       └── MorningView.swift
│
├── PulseTests/
│   ├── TriggerDetectorTests.swift
│   └── EmotionInferenceTests.swift
│
├── pulse-notebook.ipynb             # Kaggle notebook: training + API demo
├── LICENSE                          # MIT
└── README.md                        # setup instructions for judges
```

---

## Submission Checklist

| Deliverable | Notes |
|---|---|
| Public GitHub repo | MIT license, from day 1 |
| Kaggle notebook | Python: data → model training → CoreML export → Gloo demo → YouVersion demo |
| YouTube video (≤3 min) | Story arc: one person, one night. See video plan below. |
| TestFlight public link | Public beta for judges to try the app |
| Kaggle writeup (≤500 words) | Architecture, API usage, challenges, results |

### Video Story Arc
- 0:00–0:20 — Person in bed, 3am. Watch shows time + heart rate elevated.
- 0:20–0:45 — "Your watch already knows." Show overnight HRV data on phone.
- 0:45–1:15 — Watch face quietly updates. Person shifts, raises wrist. Verse is there. Psalm 4:8.
- 1:15–2:00 — Four rapid cuts: different moments, different people, different verses. Post-run exhaustion. Pre-presentation spike. Sunday morning quiet. 5-day stress trend.
- 2:00–2:30 — Screen recording: CoreML inference → Gloo API call → YouVersion fetch → watch update. Both APIs visible.
- 2:30–3:00 — "Scripture has always been for human moments. Now it knows which moment you're in."

---

## Build Timeline

| Week | Focus |
|---|---|
| 1 | Xcode project + HealthKit integration + YouVersion API key + first verse fetch |
| 2 | CoreML model training (Kaggle notebook) + import model into iOS + Gloo API integration |
| 3 | TriggerDetector + WatchConnectivity + WidgetKit complication + full-screen view |
| 4 | Morning view + smart cooldown + TestFlight + demo video + Kaggle writeup |

---

## Extensibility Roadmap (Post-Competition)

The architecture is designed to accept additional HealthKit signals with minimal changes:

- **Reproductive health** — menstrual phase as a first-class signal in `BiometricFeatures`; separate opt-in permissions flow
- **Nutrition/caffeine/alcohol** — `dietaryCaffeine` and `dietaryAlcohol` as disambiguation signals (prevents false anxiety/grief classifications)
- **State of Mind** — iOS 17 `HKStateOfMind` as a self-reported ground-truth layer
- **Multi-day stress pattern** — additional trigger in `TriggerDetector` watching 5-day HRV slope
- **Mental health assessments** — PHQ-9 / GAD-7 scores from HealthKit as longitudinal context
