# Pulse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a watchOS/iOS app that reads Apple Watch biometrics, classifies emotional state via CoreML + Gloo AI, and silently delivers a contextually resonant scripture verse to the watch face.

**Architecture:** iOS app owns all logic — HealthKit queries, CoreML inference, Gloo AI + YouVersion API calls, and WatchConnectivity. watchOS app is a pure display surface (WidgetKit complication + SwiftUI views). A stub EmotionInferenceService keeps the iOS pipeline runnable while the partner's real CoreML model is in development.

**Tech Stack:** Swift 5.9+, SwiftUI, HealthKit, WatchConnectivity, WidgetKit, CoreML, URLSession (async/await), XCTest

## Global Constraints

- iOS deployment target: 17.0+
- watchOS deployment target: 10.0+
- Swift 5.9+, async/await throughout (no Combine, no callbacks)
- No third-party dependencies — stdlib + Apple frameworks only
- All HealthKit types: read-only (`toShare: nil`)
- No user identity ever sent to any API — anonymous payloads only
- Verses cached locally in UserDefaults — nothing stored remotely
- Both Gloo AI and YouVersion APIs required and must be visibly used in final submission
- MIT license — add LICENSE file at project root before first commit
- Public GitHub repo from day one

## Partner Interface Contract (ML Model)

> **This section is for the partner building the CoreML model.** Joel builds against the stub in Task 4. The partner's model drops in when ready by replacing `PulseEmotionClassifier.mlmodel` and updating `EmotionInferenceService.swift` to use it.

**Input feature names** (exact strings — must match what coremltools generates):

| Feature | Type | Description |
|---|---|---|
| `hrv_sdnn` | Double | HRV SDNN in ms |
| `hrv_7day_slope` | Double | Normalized 7-day trend (-1 declining → +1 improving) |
| `hr_delta_from_resting` | Double | Current HR minus resting HR in bpm |
| `sleep_efficiency` | Double | 0.0–1.0 |
| `deep_sleep_pct` | Double | 0.0–1.0 |
| `rem_pct` | Double | 0.0–1.0 |
| `awakening_count` | Double | Number of wake events during sleep |
| `late_night_wakefulness` | Double | 1.0 if woke between 1am–5am, else 0.0 |
| `respiratory_rate` | Double | Breaths per minute |
| `blood_oxygen` | Double | 0–100 |
| `wrist_temp_delta` | Double | °C deviation from personal baseline (0.0 if unavailable) |
| `time_of_day_sin` | Double | sin(2π × hour / 24) |
| `time_of_day_cos` | Double | cos(2π × hour / 24) |

**Output:**
- `emotionalState`: String — one of `"sleepless"`, `"anxious"`, `"depleted"`, `"struggling"`, `"recovering"`, `"restful"`, `"resilient"`, `"unknown"`
- `emotionalStateProbability`: `[String: Double]`

**Export command:**
```python
import coremltools as ct
coreml_model = ct.converters.sklearn.convert(model, feature_names, "emotionalState")
coreml_model.save("PulseEmotionClassifier.mlmodel")
```

---

## File Map

```
pulse-scripture/
├── Pulse/                                  # iOS target
│   ├── PulseApp.swift                      # app entry point, WCSession activation
│   ├── Models/
│   │   ├── BiometricFeatures.swift         # 13-feature input struct for CoreML
│   │   ├── EmotionalState.swift            # 8-state enum + EmotionClassification
│   │   ├── GlooPayload.swift               # Encodable request + Decodable response
│   │   ├── ScriptureVerse.swift            # verse text + reference + reflection
│   │   └── SharedVerse.swift               # Codable, shared with watchOS via WCSession
│   ├── Health/
│   │   ├── HealthKitManager.swift          # auth, background delivery, sample queries
│   │   ├── BiometricPayloadBuilder.swift   # HK samples → BiometricFeatures + GlooPayload
│   │   └── TriggerDetector.swift           # watches for the 5 trigger conditions
│   ├── ML/
│   │   ├── EmotionInferenceService.swift   # stub first; wraps CoreML model when ready
│   │   └── PulseEmotionClassifier.mlmodel  # partner delivers; placeholder stub initially
│   ├── API/
│   │   ├── YouVersionAPIService.swift      # fetches verse text by reference
│   │   └── GlooAPIService.swift            # sends state, receives verse reference
│   ├── Storage/
│   │   └── VerseCache.swift                # UserDefaults persistence + cooldown logic
│   ├── Connectivity/
│   │   └── PhoneSessionManager.swift       # WCSession wrapper, iOS side
│   └── Views/
│       ├── OnboardingView.swift            # permissions + translation picker
│       └── SettingsView.swift              # translation, language, debug info
│
├── PulseWatch/                             # watchOS target
│   ├── PulseWatchApp.swift                 # watch app entry + WCSession activation
│   ├── Connectivity/
│   │   └── WatchSessionManager.swift       # WCSession wrapper, watchOS side
│   ├── Complications/
│   │   └── VerseWidget.swift               # WidgetKit timeline provider
│   └── Views/
│       ├── VerseFullView.swift             # full-screen verse on tap
│       └── MorningView.swift               # morning-specific proactive view
│
├── PulseTests/
│   ├── Mocks/
│   │   ├── MockURLSession.swift
│   │   └── MockClock.swift
│   ├── BiometricPayloadBuilderTests.swift
│   ├── TriggerDetectorTests.swift
│   ├── EmotionInferenceTests.swift
│   ├── VerseCacheTests.swift
│   ├── YouVersionAPIServiceTests.swift
│   └── GlooAPIServiceTests.swift
│
├── pulse-notebook.ipynb                    # Kaggle notebook (Python)
├── LICENSE                                 # MIT
└── README.md
```

---

## Task 1: Xcode Project Setup + Shared Models

**Files:**
- Create: Xcode project with iOS + watchOS targets
- Create: `Pulse/Models/BiometricFeatures.swift`
- Create: `Pulse/Models/EmotionalState.swift`
- Create: `Pulse/Models/GlooPayload.swift`
- Create: `Pulse/Models/ScriptureVerse.swift`
- Create: `Pulse/Models/SharedVerse.swift`
- Create: `LICENSE`

**Interfaces:**
- Produces: `BiometricFeatures`, `EmotionalState`, `EmotionClassification`, `GlooRequest`, `GlooResponse`, `ScriptureVerse`, `SharedVerse` — used by every subsequent task

- [ ] **Step 1: Create Xcode project**

  File → New → Project → App. Name: `Pulse`. Bundle ID: `com.YOURTEAM.pulse`. Language: Swift. Interface: SwiftUI. Include Tests: yes.

  Add watchOS target: File → New → Target → Watch App. Name: `PulseWatch`. Bundle ID: `com.YOURTEAM.pulse.watchkitapp`.

  Set deployment targets: iOS 17.0, watchOS 10.0.

- [ ] **Step 2: Add HealthKit entitlements**

  Select the `Pulse` target → Signing & Capabilities → + Capability → HealthKit. Check "Background Delivery" in the HealthKit options.

  In `Pulse.entitlements` confirm these keys are present:
  ```xml
  <key>com.apple.developer.healthkit</key>
  <true/>
  <key>com.apple.developer.healthkit.background-delivery</key>
  <true/>
  ```

  In `Info.plist` add:
  ```xml
  <key>NSHealthShareUsageDescription</key>
  <string>Pulse reads your heart rate, HRV, and sleep data to understand how you're feeling and deliver a scripture verse at the right moment.</string>
  ```

- [ ] **Step 3: Add background modes to Info.plist**

  ```xml
  <key>UIBackgroundModes</key>
  <array>
      <string>fetch</string>
      <string>processing</string>
  </array>
  ```

- [ ] **Step 4: Create `BiometricFeatures.swift`**

  ```swift
  struct BiometricFeatures {
      var hrv_sdnn: Double
      var hrv_7day_slope: Double
      var hr_delta_from_resting: Double
      var sleep_efficiency: Double
      var deep_sleep_pct: Double
      var rem_pct: Double
      var awakening_count: Double
      var late_night_wakefulness: Double
      var respiratory_rate: Double
      var blood_oxygen: Double
      var wrist_temp_delta: Double
      var time_of_day_sin: Double
      var time_of_day_cos: Double

      static func timeEncoding(hour: Int) -> (sin: Double, cos: Double) {
          let angle = 2 * Double.pi * Double(hour) / 24.0
          return (sin: Foundation.sin(angle), cos: Foundation.cos(angle))
      }
  }
  ```

- [ ] **Step 5: Create `EmotionalState.swift`**

  ```swift
  enum EmotionalState: String, CaseIterable {
      case sleepless, anxious, depleted, struggling
      case recovering, restful, resilient, unknown
  }

  struct EmotionClassification {
      let state: EmotionalState
      let confidence: Double
      let probabilities: [String: Double]

      var isHighConfidence: Bool { confidence >= 0.70 }
  }
  ```

- [ ] **Step 6: Create `GlooPayload.swift`**

  ```swift
  struct GlooRequest: Encodable {
      let emotionalState: String
      let stateConfidence: Double
      let supportingSignals: SupportingSignals
      let timeContext: TimeContext
      let userPreferences: UserPreferences

      struct SupportingSignals: Encodable {
          let hrvSdnnMs: Double?
          let hrDeltaBpm: Double?
          let lateNightWake: Bool
          let sleepEfficiency: Double?
          let hrvTrend: String
      }

      struct TimeContext: Encodable {
          let timeOfDay: String
          let dayOfWeek: String
      }

      struct UserPreferences: Encodable {
          let translation: String
          let language: String
      }
  }

  struct GlooResponse: Decodable {
      let scriptureTheme: String
      let verseReference: String
      let verseDisplayLabel: String
      let reflection: String?
  }
  ```

- [ ] **Step 7: Create `ScriptureVerse.swift`**

  ```swift
  struct ScriptureVerse: Codable {
      let reference: String
      let displayLabel: String
      let text: String
      let translation: String
      let reflection: String?
      let deliveredAt: Date
      let emotionalContext: String
  }
  ```

- [ ] **Step 8: Create `SharedVerse.swift`** (used by both targets via WCSession)

  Add this file to both the `Pulse` and `PulseWatch` targets:

  ```swift
  struct SharedVerse: Codable {
      let reference: String
      let displayLabel: String
      let text: String
      let reflection: String?
      let deliveredAt: Date

      static let watchContextKey = "currentVerse"

      func toDictionary() -> [String: Any] {
          let encoder = JSONEncoder()
          encoder.dateEncodingStrategy = .iso8601
          guard let data = try? encoder.encode(self),
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
          else { return [:] }
          return dict
      }

      static func from(dictionary: [String: Any]) -> SharedVerse? {
          guard let data = try? JSONSerialization.data(withJSONObject: dictionary) else { return nil }
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .iso8601
          return try? decoder.decode(SharedVerse.self, from: data)
      }
  }
  ```

- [ ] **Step 9: Add MIT license**

  Create `LICENSE` at repo root:
  ```
  MIT License

  Copyright (c) 2026 [Your Names]

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  ```

- [ ] **Step 10: Initialize git repo and push**

  ```bash
  git init
  git add .
  git commit -m "chore: project setup, shared models, MIT license"
  git remote add origin https://github.com/YOURTEAM/pulse-scripture.git
  git push -u origin main
  ```

---

## Task 2: YouVersion API Service

**Files:**
- Create: `Pulse/API/YouVersionAPIService.swift`
- Create: `PulseTests/Mocks/MockURLSession.swift`
- Create: `PulseTests/YouVersionAPIServiceTests.swift`

**Interfaces:**
- Consumes: `ScriptureVerse` (Task 1)
- Produces: `YouVersionAPIService.fetchVerse(reference:versionId:) async throws -> ScriptureVerse`

> Note: API key and base URL are provided when the competition opens July 6. Use the placeholder base URL below; update after receiving credentials. The USFM verse reference format (e.g. `PSA.4.8`) is standard YouVersion — confirm endpoint paths with the official docs when available.

- [ ] **Step 1: Create `MockURLSession.swift`**

  ```swift
  // PulseTests/Mocks/MockURLSession.swift
  import Foundation

  protocol URLSessionProtocol {
      func data(for request: URLRequest) async throws -> (Data, URLResponse)
  }

  extension URLSession: URLSessionProtocol {}

  final class MockURLSession: URLSessionProtocol {
      var stubbedData: Data = Data()
      var stubbedResponse: URLResponse = HTTPURLResponse(
          url: URL(string: "https://example.com")!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
      )!
      var stubbedError: Error?

      func data(for request: URLRequest) async throws -> (Data, URLResponse) {
          if let error = stubbedError { throw error }
          return (stubbedData, stubbedResponse)
      }
  }
  ```

- [ ] **Step 2: Write failing tests**

  ```swift
  // PulseTests/YouVersionAPIServiceTests.swift
  import XCTest
  @testable import Pulse

  final class YouVersionAPIServiceTests: XCTestCase {
      var mockSession: MockURLSession!
      var sut: YouVersionAPIService!

      override func setUp() {
          mockSession = MockURLSession()
          sut = YouVersionAPIService(session: mockSession, apiKey: "test-key")
      }

      func test_fetchVerse_parsesVerseText() async throws {
          let json = """
          {
            "data": {
              "content": "In peace I will lie down and sleep,",
              "reference": "Psalm 4:8",
              "version": { "abbreviation": "NIV" }
            }
          }
          """.data(using: .utf8)!
          mockSession.stubbedData = json

          let verse = try await sut.fetchVerse(reference: "PSA.4.8", versionId: 111)

          XCTAssertEqual(verse.text, "In peace I will lie down and sleep,")
          XCTAssertEqual(verse.displayLabel, "Psalm 4:8")
          XCTAssertEqual(verse.translation, "NIV")
      }

      func test_fetchVerse_throwsOnHTTPError() async {
          mockSession.stubbedResponse = HTTPURLResponse(
              url: URL(string: "https://example.com")!,
              statusCode: 401,
              httpVersion: nil,
              headerFields: nil
          )!

          do {
              _ = try await sut.fetchVerse(reference: "PSA.4.8", versionId: 111)
              XCTFail("Expected throw")
          } catch YouVersionAPIService.APIError.httpError(let code) {
              XCTAssertEqual(code, 401)
          } catch {
              XCTFail("Unexpected error: \(error)")
          }
      }
  }
  ```

- [ ] **Step 3: Run tests — verify they fail**

  In Xcode: Cmd+U. Both tests should fail with "cannot find type YouVersionAPIService".

- [ ] **Step 4: Create `YouVersionAPIService.swift`**

  ```swift
  import Foundation

  final class YouVersionAPIService {
      enum APIError: Error {
          case httpError(Int)
          case decodingError
      }

      private let session: URLSessionProtocol
      private let apiKey: String
      private let baseURL = "https://api.youversion.com/v1"  // update after July 6 with real URL

      init(session: URLSessionProtocol = URLSession.shared, apiKey: String) {
          self.session = session
          self.apiKey = apiKey
      }

      func fetchVerse(reference: String, versionId: Int) async throws -> ScriptureVerse {
          var request = URLRequest(url: URL(string: "\(baseURL)/bible/verse/\(versionId)/\(reference)")!)
          request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
          request.setValue("application/json", forHTTPHeaderField: "Accept")

          let (data, response) = try await session.data(for: request)

          if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
              throw APIError.httpError(http.statusCode)
          }

          guard let parsed = try? JSONDecoder().decode(YouVersionVerseResponse.self, from: data) else {
              throw APIError.decodingError
          }

          return ScriptureVerse(
              reference: reference,
              displayLabel: parsed.data.reference,
              text: parsed.data.content,
              translation: parsed.data.version.abbreviation,
              reflection: nil,
              deliveredAt: Date(),
              emotionalContext: ""
          )
      }

      // MARK: - Private response types

      private struct YouVersionVerseResponse: Decodable {
          let data: VerseData
          struct VerseData: Decodable {
              let content: String
              let reference: String
              let version: VersionInfo
          }
          struct VersionInfo: Decodable {
              let abbreviation: String
          }
      }
  }
  ```

- [ ] **Step 5: Run tests — verify they pass**

  Cmd+U. Both YouVersion tests should be green.

- [ ] **Step 6: Commit**

  ```bash
  git add Pulse/API/YouVersionAPIService.swift PulseTests/Mocks/MockURLSession.swift PulseTests/YouVersionAPIServiceTests.swift
  git commit -m "feat: YouVersion API service with verse fetch"
  ```

---

## Task 3: Gloo AI Service

**Files:**
- Create: `Pulse/API/GlooAPIService.swift`
- Create: `PulseTests/GlooAPIServiceTests.swift`

**Interfaces:**
- Consumes: `GlooRequest`, `GlooResponse` (Task 1); `MockURLSession` (Task 2)
- Produces: `GlooAPIService.fetchVerse(for:preferences:) async throws -> GlooResponse`

> Note: Gloo AI Studio API endpoint and auth scheme are provided when competition opens July 6. The request/response shape below matches the spec design — update after receiving official API docs. The `baseURL` and auth header name are placeholders.

- [ ] **Step 1: Write failing tests**

  ```swift
  // PulseTests/GlooAPIServiceTests.swift
  import XCTest
  @testable import Pulse

  final class GlooAPIServiceTests: XCTestCase {
      var mockSession: MockURLSession!
      var sut: GlooAPIService!

      override func setUp() {
          mockSession = MockURLSession()
          sut = GlooAPIService(session: mockSession, apiKey: "test-key")
      }

      func test_fetchVerse_returnsVerseReference() async throws {
          let json = """
          {
            "scriptureTheme": "peace_in_sleeplessness",
            "verseReference": "PSA.4.8",
            "verseDisplayLabel": "Psalm 4:8",
            "reflection": "Your body is restless tonight. You are still held."
          }
          """.data(using: .utf8)!
          mockSession.stubbedData = json

          let classification = EmotionClassification(
              state: .sleepless,
              confidence: 0.89,
              probabilities: ["sleepless": 0.89]
          )
          let prefs = GlooAPIService.UserPreferences(translation: "NIV", language: "en")

          let response = try await sut.fetchVerse(for: classification, preferences: prefs)

          XCTAssertEqual(response.verseReference, "PSA.4.8")
          XCTAssertEqual(response.verseDisplayLabel, "Psalm 4:8")
          XCTAssertEqual(response.reflection, "Your body is restless tonight. You are still held.")
      }

      func test_fetchVerse_throwsOn500() async {
          mockSession.stubbedResponse = HTTPURLResponse(
              url: URL(string: "https://example.com")!,
              statusCode: 500, httpVersion: nil, headerFields: nil
          )!

          let classification = EmotionClassification(state: .unknown, confidence: 0.0, probabilities: [:])
          let prefs = GlooAPIService.UserPreferences(translation: "NIV", language: "en")

          do {
              _ = try await sut.fetchVerse(for: classification, preferences: prefs)
              XCTFail("Expected throw")
          } catch GlooAPIService.APIError.httpError(let code) {
              XCTAssertEqual(code, 500)
          } catch {
              XCTFail("Unexpected error: \(error)")
          }
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail**

  Cmd+U. Both tests should fail with "cannot find type GlooAPIService".

- [ ] **Step 3: Create `GlooAPIService.swift`**

  ```swift
  import Foundation

  final class GlooAPIService {
      enum APIError: Error {
          case httpError(Int)
          case decodingError
      }

      struct UserPreferences {
          let translation: String
          let language: String
      }

      private let session: URLSessionProtocol
      private let apiKey: String
      private let baseURL = "https://api.gloo.ai/v1"  // update after July 6 with real URL

      init(session: URLSessionProtocol = URLSession.shared, apiKey: String) {
          self.session = session
          self.apiKey = apiKey
      }

      func fetchVerse(
          for classification: EmotionClassification,
          biometricContext: BiometricContext? = nil,
          preferences: UserPreferences
      ) async throws -> GlooResponse {
          let body = buildRequest(classification: classification,
                                  context: biometricContext,
                                  preferences: preferences)

          var request = URLRequest(url: URL(string: "\(baseURL)/scripture/verse")!)
          request.httpMethod = "POST"
          request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")  // update auth scheme after July 6
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          let encoder = JSONEncoder()
          encoder.keyEncodingStrategy = .convertToSnakeCase
          request.httpBody = try encoder.encode(body)

          let (data, response) = try await session.data(for: request)

          if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
              throw APIError.httpError(http.statusCode)
          }

          let decoder = JSONDecoder()
          decoder.keyDecodingStrategy = .convertFromSnakeCase
          guard let parsed = try? decoder.decode(GlooResponse.self, from: data) else {
              throw APIError.decodingError
          }
          return parsed
      }

      private func buildRequest(
          classification: EmotionClassification,
          context: BiometricContext?,
          preferences: UserPreferences
      ) -> GlooRequest {
          let hour = Calendar.current.component(.hour, from: Date())
          let formatter = DateFormatter()
          formatter.dateFormat = "HH:mm"
          let dayFormatter = DateFormatter()
          dayFormatter.dateFormat = "EEEE"

          return GlooRequest(
              emotionalState: classification.state.rawValue,
              stateConfidence: classification.confidence,
              supportingSignals: GlooRequest.SupportingSignals(
                  hrvSdnnMs: context?.hrvSdnn,
                  hrDeltaBpm: context?.hrDelta,
                  lateNightWake: (1...5).contains(hour) && (context?.hrDelta ?? 0) > 10,
                  sleepEfficiency: context?.sleepEfficiency,
                  hrvTrend: context?.hrvTrend ?? "stable"
              ),
              timeContext: GlooRequest.TimeContext(
                  timeOfDay: formatter.string(from: Date()),
                  dayOfWeek: dayFormatter.string(from: Date())
              ),
              userPreferences: GlooRequest.UserPreferences(
                  translation: preferences.translation,
                  language: preferences.language
              )
          )
      }
  }

  struct BiometricContext {
      let hrvSdnn: Double?
      let hrDelta: Double?
      let sleepEfficiency: Double?
      let hrvTrend: String
  }
  ```

- [ ] **Step 4: Run tests — verify they pass**

  Cmd+U. Both Gloo tests should be green.

- [ ] **Step 5: Commit**

  ```bash
  git add Pulse/API/GlooAPIService.swift PulseTests/GlooAPIServiceTests.swift
  git commit -m "feat: Gloo AI service with verse fetch"
  ```

---

## Task 4: CoreML Stub (EmotionInferenceService)

> **Partner note:** This task creates a stub so the iOS app pipeline runs immediately. When the real `.mlmodel` is ready, replace the stub implementation in `EmotionInferenceService.swift` with the CoreML call. The interface (input/output types) does not change.

**Files:**
- Create: `Pulse/ML/EmotionInferenceService.swift`
- Create: `PulseTests/EmotionInferenceTests.swift`

**Interfaces:**
- Consumes: `BiometricFeatures`, `EmotionClassification`, `EmotionalState` (Task 1)
- Produces: `EmotionInferenceService.classify(features:) -> EmotionClassification`

- [ ] **Step 1: Write failing tests**

  ```swift
  // PulseTests/EmotionInferenceTests.swift
  import XCTest
  @testable import Pulse

  final class EmotionInferenceTests: XCTestCase {
      var sut: EmotionInferenceService!

      override func setUp() {
          sut = EmotionInferenceService()
      }

      func test_classify_returnsClassification() {
          let features = makeFeatures(hrvSdnn: 17.0, hrDelta: 22.0, hour: 3)
          let result = sut.classify(features: features)
          XCTAssertNotNil(result)
          XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
          XCTAssertLessThanOrEqual(result.confidence, 1.0)
      }

      func test_classify_returnsValidState() {
          let features = makeFeatures(hrvSdnn: 17.0, hrDelta: 22.0, hour: 3)
          let result = sut.classify(features: features)
          XCTAssertTrue(EmotionalState.allCases.contains(result.state))
      }

      // MARK: - Helpers

      private func makeFeatures(hrvSdnn: Double, hrDelta: Double, hour: Int) -> BiometricFeatures {
          let timeEnc = BiometricFeatures.timeEncoding(hour: hour)
          return BiometricFeatures(
              hrv_sdnn: hrvSdnn,
              hrv_7day_slope: 0.0,
              hr_delta_from_resting: hrDelta,
              sleep_efficiency: 0.6,
              deep_sleep_pct: 0.08,
              rem_pct: 0.12,
              awakening_count: 3,
              late_night_wakefulness: hour >= 1 && hour <= 5 ? 1.0 : 0.0,
              respiratory_rate: 18.0,
              blood_oxygen: 96.0,
              wrist_temp_delta: 0.0,
              time_of_day_sin: timeEnc.sin,
              time_of_day_cos: timeEnc.cos
          )
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail**

  Cmd+U. Tests fail with "cannot find type EmotionInferenceService".

- [ ] **Step 3: Create stub `EmotionInferenceService.swift`**

  ```swift
  import Foundation

  final class EmotionInferenceService {
      // STUB: Returns rule-based classification until partner's CoreML model is ready.
      // To integrate the real model:
      //   1. Add PulseEmotionClassifier.mlmodel to the ML/ folder
      //   2. Replace this implementation with the CoreML call below
      //
      // Real implementation:
      //   private let model = try! PulseEmotionClassifier(configuration: MLModelConfiguration())
      //   func classify(features: BiometricFeatures) -> EmotionClassification {
      //       let input = PulseEmotionClassifierInput(
      //           hrv_sdnn: features.hrv_sdnn, ... )
      //       let output = try! model.prediction(input: input)
      //       return EmotionClassification(
      //           state: EmotionalState(rawValue: output.emotionalState) ?? .unknown,
      //           confidence: output.emotionalStateProbability[output.emotionalState] ?? 0,
      //           probabilities: output.emotionalStateProbability)
      //   }

      func classify(features: BiometricFeatures) -> EmotionClassification {
          let state = stubClassify(features: features)
          return EmotionClassification(
              state: state,
              confidence: 0.75,
              probabilities: [state.rawValue: 0.75]
          )
      }

      private func stubClassify(features: BiometricFeatures) -> EmotionalState {
          let hour = Calendar.current.component(.hour, from: Date())
          if features.late_night_wakefulness > 0.5 && features.hr_delta_from_resting > 10 {
              return .sleepless
          }
          if features.hr_delta_from_resting > 20 && features.sleep_efficiency < 0.7 {
              return .depleted
          }
          if features.hr_delta_from_resting > 20 {
              return .anxious
          }
          if features.hrv_7day_slope < -0.3 {
              return .struggling
          }
          if features.hrv_sdnn > 45 && features.hr_delta_from_resting < 5 {
              return .restful
          }
          return .unknown
      }
  }
  ```

- [ ] **Step 4: Run tests — verify they pass**

  Cmd+U. Both inference tests should be green.

- [ ] **Step 5: Commit**

  ```bash
  git add Pulse/ML/EmotionInferenceService.swift PulseTests/EmotionInferenceTests.swift
  git commit -m "feat: CoreML stub emotion inference service"
  ```

---

## Task 5: HealthKitManager

**Files:**
- Create: `Pulse/Health/HealthKitManager.swift`

> Unit testing HealthKit requires a real device and authorized HealthStore — no unit tests for this task. Test manually on device after Task 9 integration.

**Interfaces:**
- Produces:
  - `HealthKitManager.requestAuthorization() async throws`
  - `HealthKitManager.latestHRV() async -> Double?`
  - `HealthKitManager.latestHeartRate() async -> Double?`
  - `HealthKitManager.restingHeartRate() async -> Double?`
  - `HealthKitManager.sleepSummary(for:) async -> SleepSummary`
  - `HealthKitManager.latestRespiratoryRate() async -> Double?`
  - `HealthKitManager.latestBloodOxygen() async -> Double?`
  - `HealthKitManager.latestWristTemp() async -> Double?`
  - `HealthKitManager.enableBackgroundDelivery(handler:)`

- [ ] **Step 1: Create `HealthKitManager.swift`**

  ```swift
  import HealthKit

  struct SleepSummary {
      let efficiency: Double       // 0.0–1.0
      let deepSleepPct: Double
      let remPct: Double
      let awakeningCount: Double
      let hadLateNightWakefulness: Bool
      static let empty = SleepSummary(efficiency: 0, deepSleepPct: 0,
                                       remPct: 0, awakeningCount: 0,
                                       hadLateNightWakefulness: false)
  }

  @MainActor
  final class HealthKitManager: ObservableObject {
      private let store = HKHealthStore()

      private let readTypes: Set<HKObjectType> = [
          HKQuantityType(.heartRateVariabilitySDNN),
          HKQuantityType(.heartRate),
          HKQuantityType(.restingHeartRate),
          HKQuantityType(.respiratoryRate),
          HKQuantityType(.oxygenSaturation),
          HKQuantityType(.appleSleepingWristTemperature),
          HKCategoryType(.sleepAnalysis)
      ]

      func requestAuthorization() async throws {
          guard HKHealthStore.isHealthDataAvailable() else {
              throw HealthKitError.notAvailable
          }
          try await store.requestAuthorization(toShare: nil, read: readTypes)
      }

      func latestHRV() async -> Double? {
          await latestQuantity(for: .heartRateVariabilitySDNN, unit: HKUnit(from: "ms"))
      }

      func latestHeartRate() async -> Double? {
          await latestQuantity(for: .heartRate, unit: HKUnit(from: "count/min"))
      }

      func restingHeartRate() async -> Double? {
          await latestQuantity(for: .restingHeartRate, unit: HKUnit(from: "count/min"))
      }

      func latestRespiratoryRate() async -> Double? {
          await latestQuantity(for: .respiratoryRate, unit: HKUnit(from: "count/min"))
      }

      func latestBloodOxygen() async -> Double? {
          guard let raw = await latestQuantity(for: .oxygenSaturation, unit: .percent()) else { return nil }
          return raw * 100.0
      }

      func latestWristTemp() async -> Double? {
          await latestQuantity(for: .appleSleepingWristTemperature, unit: .degreeCelsius())
      }

      func sleepSummary(for date: Date = Date()) async -> SleepSummary {
          let calendar = Calendar.current
          let start = calendar.startOfDay(for: date).addingTimeInterval(-86400)
          let end = calendar.startOfDay(for: date).addingTimeInterval(43200)
          let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
          let type = HKCategoryType(.sleepAnalysis)

          return await withCheckedContinuation { continuation in
              let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                        limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                  guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                      continuation.resume(returning: .empty)
                      return
                  }
                  continuation.resume(returning: Self.computeSleepSummary(from: samples))
              }
              store.execute(query)
          }
      }

      func enableBackgroundDelivery(handler: @escaping () -> Void) {
          let typesToObserve: [HKQuantityTypeIdentifier] = [.heartRateVariabilitySDNN, .heartRate]
          for identifier in typesToObserve {
              let type = HKQuantityType(identifier)
              store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
              let query = HKObserverQuery(sampleType: type, predicate: nil) { _, _, _ in
                  handler()
              }
              store.execute(query)
          }
      }

      // MARK: - Private helpers

      private func latestQuantity(for identifier: HKQuantityTypeIdentifier,
                                   unit: HKUnit) async -> Double? {
          let type = HKQuantityType(identifier)
          let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
          return await withCheckedContinuation { continuation in
              let query = HKSampleQuery(sampleType: type, predicate: nil,
                                        limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                  let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                  continuation.resume(returning: value)
              }
              store.execute(query)
          }
      }

      private static func computeSleepSummary(from samples: [HKCategorySample]) -> SleepSummary {
          var deepSeconds = 0.0
          var remSeconds = 0.0
          var totalSeconds = 0.0
          var awakenings = 0
          var hadLateWake = false

          for sample in samples {
              let duration = sample.endDate.timeIntervalSince(sample.startDate)
              let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
              switch value {
              case .asleepDeep:  deepSeconds += duration; totalSeconds += duration
              case .asleepREM:   remSeconds += duration; totalSeconds += duration
              case .asleepCore:  totalSeconds += duration
              case .awake:
                  awakenings += 1
                  let hour = Calendar.current.component(.hour, from: sample.startDate)
                  if (1...5).contains(hour) { hadLateWake = true }
              default: break
              }
          }

          let total = max(totalSeconds, 1)
          return SleepSummary(
              efficiency: min(totalSeconds / (totalSeconds + Double(awakenings) * 600), 1.0),
              deepSleepPct: deepSeconds / total,
              remPct: remSeconds / total,
              awakeningCount: Double(awakenings),
              hadLateNightWakefulness: hadLateWake
          )
      }

      enum HealthKitError: Error {
          case notAvailable
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add Pulse/Health/HealthKitManager.swift
  git commit -m "feat: HealthKitManager with background delivery"
  ```

---

## Task 6: BiometricPayloadBuilder

**Files:**
- Create: `Pulse/Health/BiometricPayloadBuilder.swift`
- Create: `PulseTests/BiometricPayloadBuilderTests.swift`

**Interfaces:**
- Consumes: `BiometricFeatures`, `BiometricContext`, `SleepSummary` (Task 5)
- Produces: `BiometricPayloadBuilder.build(hrv:restingHR:currentHR:sleep:respiratory:bloodOxygen:wristTemp:) -> (BiometricFeatures, BiometricContext)`

- [ ] **Step 1: Write failing tests**

  ```swift
  // PulseTests/BiometricPayloadBuilderTests.swift
  import XCTest
  @testable import Pulse

  final class BiometricPayloadBuilderTests: XCTestCase {
      func test_hrDelta_calculatedCorrectly() {
          let (features, _) = BiometricPayloadBuilder.build(
              hrv: 20.0, restingHR: 65.0, currentHR: 90.0,
              sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
          )
          XCTAssertEqual(features.hr_delta_from_resting, 25.0, accuracy: 0.01)
      }

      func test_lateNightWakefulness_setFromSleep() {
          let sleep = SleepSummary(efficiency: 0.6, deepSleepPct: 0.08, remPct: 0.10,
                                    awakeningCount: 2, hadLateNightWakefulness: true)
          let (features, _) = BiometricPayloadBuilder.build(
              hrv: 20.0, restingHR: 65.0, currentHR: 70.0,
              sleep: sleep, respiratory: nil, bloodOxygen: nil, wristTemp: nil
          )
          XCTAssertEqual(features.late_night_wakefulness, 1.0)
      }

      func test_lateNightWakefulness_clearWhenNoWake() {
          let sleep = SleepSummary(efficiency: 0.85, deepSleepPct: 0.2, remPct: 0.2,
                                    awakeningCount: 0, hadLateNightWakefulness: false)
          let (features, _) = BiometricPayloadBuilder.build(
              hrv: 50.0, restingHR: 60.0, currentHR: 62.0,
              sleep: sleep, respiratory: nil, bloodOxygen: nil, wristTemp: nil
          )
          XCTAssertEqual(features.late_night_wakefulness, 0.0)
      }

      func test_missingHRV_defaultsToZero() {
          let (features, _) = BiometricPayloadBuilder.build(
              hrv: nil, restingHR: 65.0, currentHR: 70.0,
              sleep: .empty, respiratory: nil, bloodOxygen: nil, wristTemp: nil
          )
          XCTAssertEqual(features.hrv_sdnn, 0.0)
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail**

  Cmd+U. Tests fail with "cannot find type BiometricPayloadBuilder".

- [ ] **Step 3: Create `BiometricPayloadBuilder.swift`**

  ```swift
  import Foundation

  enum BiometricPayloadBuilder {
      static func build(
          hrv: Double?,
          restingHR: Double?,
          currentHR: Double?,
          sleep: SleepSummary,
          respiratory: Double?,
          bloodOxygen: Double?,
          wristTemp: Double?,
          previousHRVReadings: [Double] = []
      ) -> (BiometricFeatures, BiometricContext) {
          let hrDelta = (currentHR ?? 0) - (restingHR ?? 0)
          let hour = Calendar.current.component(.hour, from: Date())
          let timeEnc = BiometricFeatures.timeEncoding(hour: hour)
          let slope = computeHRVSlope(readings: previousHRVReadings)

          let features = BiometricFeatures(
              hrv_sdnn: hrv ?? 0.0,
              hrv_7day_slope: slope,
              hr_delta_from_resting: max(hrDelta, 0),
              sleep_efficiency: sleep.efficiency,
              deep_sleep_pct: sleep.deepSleepPct,
              rem_pct: sleep.remPct,
              awakening_count: sleep.awakeningCount,
              late_night_wakefulness: sleep.hadLateNightWakefulness ? 1.0 : 0.0,
              respiratory_rate: respiratory ?? 0.0,
              blood_oxygen: bloodOxygen ?? 0.0,
              wrist_temp_delta: wristTemp ?? 0.0,
              time_of_day_sin: timeEnc.sin,
              time_of_day_cos: timeEnc.cos
          )

          let context = BiometricContext(
              hrvSdnn: hrv.map { round($0 * 10) / 10 },
              hrDelta: hrDelta > 0 ? round(hrDelta) : nil,
              sleepEfficiency: sleep.efficiency > 0 ? round(sleep.efficiency * 100) / 100 : nil,
              hrvTrend: trendLabel(slope: slope)
          )

          return (features, context)
      }

      private static func computeHRVSlope(readings: [Double]) -> Double {
          guard readings.count >= 3 else { return 0.0 }
          let n = Double(readings.count)
          let xs = (0..<readings.count).map { Double($0) }
          let meanX = xs.reduce(0, +) / n
          let meanY = readings.reduce(0, +) / n
          let num = zip(xs, readings).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +)
          let den = xs.map { ($0 - meanX) * ($0 - meanX) }.reduce(0, +)
          let rawSlope = den == 0 ? 0 : num / den
          return max(-1.0, min(1.0, rawSlope / 5.0))
      }

      private static func trendLabel(slope: Double) -> String {
          if slope < -0.2 { return "declining" }
          if slope > 0.2  { return "improving" }
          return "stable"
      }
  }
  ```

- [ ] **Step 4: Run tests — verify they pass**

  Cmd+U. All four tests should be green.

- [ ] **Step 5: Commit**

  ```bash
  git add Pulse/Health/BiometricPayloadBuilder.swift PulseTests/BiometricPayloadBuilderTests.swift
  git commit -m "feat: BiometricPayloadBuilder with HRV slope and sleep mapping"
  ```

---

## Task 7: VerseCache + Cooldown

**Files:**
- Create: `Pulse/Storage/VerseCache.swift`
- Create: `PulseTests/Mocks/MockClock.swift`
- Create: `PulseTests/VerseCacheTests.swift`

**Interfaces:**
- Consumes: `ScriptureVerse`, `SharedVerse` (Task 1)
- Produces:
  - `VerseCache.canDeliver: Bool`
  - `VerseCache.store(verse:ScriptureVerse)`
  - `VerseCache.currentVerse: ScriptureVerse?`
  - `VerseCache.recordEngagement(tapped:Bool)`

- [ ] **Step 1: Create `MockClock.swift`**

  ```swift
  // PulseTests/Mocks/MockClock.swift
  protocol Clock {
      var now: Date { get }
  }

  struct SystemClock: Clock {
      var now: Date { Date() }
  }

  struct MockClock: Clock {
      let fixedDate: Date
      var now: Date { fixedDate }

      init(offset: TimeInterval = 0) {
          fixedDate = Date().addingTimeInterval(offset)
      }
  }
  ```

- [ ] **Step 2: Write failing tests**

  ```swift
  // PulseTests/VerseCacheTests.swift
  import XCTest
  @testable import Pulse

  final class VerseCacheTests: XCTestCase {
      func test_canDeliverIsTrue_whenNothingDelivered() {
          let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
          XCTAssertTrue(cache.canDeliver)
      }

      func test_canDeliverIsFalse_withinCooldown() {
          let defaults = makeDefaults()
          let cache = VerseCache(clock: MockClock(), defaults: defaults)
          cache.store(verse: makeVerse())
          XCTAssertFalse(cache.canDeliver)
      }

      func test_canDeliverIsTrue_afterCooldownExpires() {
          let defaults = makeDefaults()
          let cache = VerseCache(clock: MockClock(), defaults: defaults)
          cache.store(verse: makeVerse())
          let later = VerseCache(clock: MockClock(offset: 7201), defaults: defaults)
          XCTAssertTrue(later.canDeliver)
      }

      func test_engagementLowEnough_extendsToShortCooldown_whenTapped() {
          let defaults = makeDefaults()
          let cache = VerseCache(clock: MockClock(), defaults: defaults)
          cache.store(verse: makeVerse())
          cache.recordEngagement(tapped: true)
          // Tapped → shorter cooldown (1 hour = 3600s). At 3601s it should be available.
          let soonAfter = VerseCache(clock: MockClock(offset: 3601), defaults: defaults)
          XCTAssertTrue(soonAfter.canDeliver)
      }

      func test_currentVerse_isNilInitially() {
          let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
          XCTAssertNil(cache.currentVerse)
      }

      func test_currentVerse_returnsMostRecentlyStored() {
          let cache = VerseCache(clock: MockClock(), defaults: makeDefaults())
          let verse = makeVerse()
          cache.store(verse: verse)
          XCTAssertEqual(cache.currentVerse?.reference, "PSA.4.8")
      }

      // MARK: - Helpers

      private func makeDefaults() -> UserDefaults {
          let d = UserDefaults(suiteName: UUID().uuidString)!
          d.removePersistentDomain(forName: d.description)
          return d
      }

      private func makeVerse() -> ScriptureVerse {
          ScriptureVerse(reference: "PSA.4.8", displayLabel: "Psalm 4:8",
                         text: "In peace I will lie down and sleep",
                         translation: "NIV", reflection: nil,
                         deliveredAt: Date(), emotionalContext: "sleepless")
      }
  }
  ```

- [ ] **Step 3: Run tests — verify they fail**

  Cmd+U. All tests fail.

- [ ] **Step 4: Create `VerseCache.swift`**

  ```swift
  import Foundation

  final class VerseCache {
      private let defaults: UserDefaults
      private let clock: Clock
      private let baseCooldown: TimeInterval = 7200    // 2 hours default
      private let shortCooldown: TimeInterval = 3600   // 1 hour if user tapped
      private let longCooldown: TimeInterval = 14400   // 4 hours if user dismissed

      private enum Keys {
          static let lastDelivery = "pulse.lastDelivery"
          static let cooldownDuration = "pulse.cooldownDuration"
          static let currentVerse = "pulse.currentVerse"
      }

      init(clock: Clock = SystemClock(), defaults: UserDefaults = .standard) {
          self.clock = clock
          self.defaults = defaults
      }

      var canDeliver: Bool {
          guard let last = defaults.object(forKey: Keys.lastDelivery) as? Date else { return true }
          let cooldown = defaults.double(forKey: Keys.cooldownDuration)
          let effective = cooldown > 0 ? cooldown : baseCooldown
          return clock.now.timeIntervalSince(last) >= effective
      }

      func store(verse: ScriptureVerse) {
          defaults.set(clock.now, forKey: Keys.lastDelivery)
          defaults.set(baseCooldown, forKey: Keys.cooldownDuration)
          if let data = try? JSONEncoder().encode(verse) {
              defaults.set(data, forKey: Keys.currentVerse)
          }
      }

      func recordEngagement(tapped: Bool) {
          defaults.set(tapped ? shortCooldown : longCooldown, forKey: Keys.cooldownDuration)
      }

      var currentVerse: ScriptureVerse? {
          guard let data = defaults.data(forKey: Keys.currentVerse) else { return nil }
          return try? JSONDecoder().decode(ScriptureVerse.self, from: data)
      }

      var currentSharedVerse: SharedVerse? {
          guard let verse = currentVerse else { return nil }
          return SharedVerse(reference: verse.reference, displayLabel: verse.displayLabel,
                             text: verse.text, reflection: verse.reflection,
                             deliveredAt: verse.deliveredAt)
      }
  }
  ```

- [ ] **Step 5: Run tests — verify they pass**

  Cmd+U. All VerseCache tests should be green.

- [ ] **Step 6: Commit**

  ```bash
  git add Pulse/Storage/VerseCache.swift PulseTests/Mocks/MockClock.swift PulseTests/VerseCacheTests.swift
  git commit -m "feat: VerseCache with adaptive cooldown"
  ```

---

## Task 8: TriggerDetector

**Files:**
- Create: `Pulse/Health/TriggerDetector.swift`
- Create: `PulseTests/TriggerDetectorTests.swift`

**Interfaces:**
- Consumes: `VerseCache.canDeliver` (Task 7); `HealthKitManager` signals (Task 5)
- Produces: `TriggerDetector.evaluate(hrv:restingHR:currentHR:sleep:hour:workoutActive:cache:) -> TriggerReason?`

- [ ] **Step 1: Write failing tests**

  ```swift
  // PulseTests/TriggerDetectorTests.swift
  import XCTest
  @testable import Pulse

  final class TriggerDetectorTests: XCTestCase {
      var sut: TriggerDetector!

      override func setUp() { sut = TriggerDetector() }

      func test_3amWake_triggersFires() {
          let reason = sut.evaluate(hrv: 15, restingHR: 65, currentHR: 84,
                                    sleep: makeSleep(lateWake: true), hour: 3,
                                    workoutActive: false, canDeliver: true)
          XCTAssertEqual(reason, .lateNightWakefulness)
      }

      func test_workoutActive_suppressesDaytimeTrigger() {
          let reason = sut.evaluate(hrv: 15, restingHR: 65, currentHR: 120,
                                    sleep: .empty, hour: 14,
                                    workoutActive: true, canDeliver: true)
          XCTAssertNil(reason)
      }

      func test_inCooldown_suppressesAllTriggers() {
          let reason = sut.evaluate(hrv: 15, restingHR: 65, currentHR: 90,
                                    sleep: makeSleep(lateWake: true), hour: 3,
                                    workoutActive: false, canDeliver: false)
          XCTAssertNil(reason)
      }

      func test_morningHRV_firesAfterSleep() {
          let reason = sut.evaluate(hrv: 18, restingHR: 65, currentHR: 67,
                                    sleep: makeSleep(lateWake: false), hour: 7,
                                    workoutActive: false, canDeliver: true)
          XCTAssertEqual(reason, .morningHRVAvailable)
      }

      func test_sustainedDaytimeStress_fires() {
          let reason = sut.evaluate(hrv: 22, restingHR: 65, currentHR: 90,
                                    sleep: .empty, hour: 14,
                                    workoutActive: false, canDeliver: true)
          XCTAssertEqual(reason, .sustainedDaytimeStress)
      }

      func test_noTrigger_whenAllNormal() {
          let reason = sut.evaluate(hrv: 50, restingHR: 60, currentHR: 62,
                                    sleep: makeSleep(lateWake: false), hour: 15,
                                    workoutActive: false, canDeliver: true)
          XCTAssertNil(reason)
      }

      // MARK: - Helpers
      private func makeSleep(lateWake: Bool) -> SleepSummary {
          SleepSummary(efficiency: 0.75, deepSleepPct: 0.15, remPct: 0.20,
                       awakeningCount: 1, hadLateNightWakefulness: lateWake)
      }
  }
  ```

- [ ] **Step 2: Run tests — verify they fail**

  Cmd+U. All fail with "cannot find type TriggerDetector".

- [ ] **Step 3: Create `TriggerDetector.swift`**

  ```swift
  import Foundation

  enum TriggerReason: Equatable {
      case morningHRVAvailable
      case lateNightWakefulness
      case postWorkoutRecovery
      case sustainedDaytimeStress
      case fallback24Hour
  }

  final class TriggerDetector {
      private let morningHours = 5...10
      private let nightHours: [Int] = [1, 2, 3, 4, 5]
      private let stressHRDeltaThreshold = 20.0
      private let lateNightHRDeltaThreshold = 15.0

      func evaluate(
          hrv: Double?,
          restingHR: Double?,
          currentHR: Double?,
          sleep: SleepSummary,
          hour: Int,
          workoutActive: Bool,
          canDeliver: Bool,
          hoursSinceLastVerse: Double = 0,
          hrWasElevatedPostWorkout: Bool = false
      ) -> TriggerReason? {
          guard canDeliver else { return nil }

          let hrDelta = (currentHR ?? 0) - (restingHR ?? 0)

          // 24-hour fallback — fires in the morning if nothing else has triggered
          if hoursSinceLastVerse >= 24 && morningHours.contains(hour) {
              return .fallback24Hour
          }

          if sleep.hadLateNightWakefulness && hrDelta > lateNightHRDeltaThreshold
              && nightHours.contains(hour) && !workoutActive {
              return .lateNightWakefulness
          }

          if morningHours.contains(hour) && hrv != nil && !workoutActive {
              return .morningHRVAvailable
          }

          // Post-workout: HR was elevated (workout ended) and has now dropped toward resting
          if hrWasElevatedPostWorkout && hrDelta < 15 && !workoutActive {
              return .postWorkoutRecovery
          }

          if !workoutActive && hrDelta > stressHRDeltaThreshold {
              if nightHours.contains(hour) { return .lateNightWakefulness }
              return .sustainedDaytimeStress
          }

          return nil
      }
  }
  ```

- [ ] **Step 4: Run tests — verify they pass**

  Cmd+U. All TriggerDetector tests should be green.

- [ ] **Step 5: Commit**

  ```bash
  git add Pulse/Health/TriggerDetector.swift PulseTests/TriggerDetectorTests.swift
  git commit -m "feat: TriggerDetector with 5 trigger conditions"
  ```

---

## Task 9: iOS Pipeline Integration

Wire all services into a single `VerseOrchestrator` that the app calls.

**Files:**
- Create: `Pulse/VerseOrchestrator.swift`

**Interfaces:**
- Consumes: All services from Tasks 2–8
- Produces: `VerseOrchestrator.run() async` — full pipeline end-to-end

- [ ] **Step 1: Create `VerseOrchestrator.swift`**

  ```swift
  import Foundation

  @MainActor
  final class VerseOrchestrator: ObservableObject {
      @Published var currentVerse: ScriptureVerse?

      private let hkManager: HealthKitManager
      private let inference: EmotionInferenceService
      private let glooService: GlooAPIService
      private let youVersion: YouVersionAPIService
      private let cache: VerseCache
      private let trigger: TriggerDetector
      private let preferences: GlooAPIService.UserPreferences

      init(
          hkManager: HealthKitManager = HealthKitManager(),
          inference: EmotionInferenceService = EmotionInferenceService(),
          glooService: GlooAPIService,
          youVersion: YouVersionAPIService,
          cache: VerseCache = VerseCache(),
          preferences: GlooAPIService.UserPreferences
      ) {
          self.hkManager = hkManager
          self.inference = inference
          self.glooService = glooService
          self.youVersion = youVersion
          self.cache = cache
          self.trigger = TriggerDetector()
          self.preferences = preferences
          self.currentVerse = cache.currentVerse
      }

      func run() async {
          guard cache.canDeliver else { return }

          async let hrv = hkManager.latestHRV()
          async let restingHR = hkManager.restingHeartRate()
          async let currentHR = hkManager.latestHeartRate()
          async let sleep = hkManager.sleepSummary()
          async let respiratory = hkManager.latestRespiratoryRate()
          async let bloodOxygen = hkManager.latestBloodOxygen()
          async let wristTemp = hkManager.latestWristTemp()

          let (hrvVal, restingVal, currentVal, sleepVal, respVal, o2Val, tempVal) =
              await (hrv, restingHR, currentHR, sleep, respiratory, bloodOxygen, wristTemp)

          let hour = Calendar.current.component(.hour, from: Date())
          guard trigger.evaluate(hrv: hrvVal, restingHR: restingVal, currentHR: currentVal,
                                  sleep: sleepVal, hour: hour, workoutActive: false,
                                  canDeliver: cache.canDeliver) != nil else { return }

          let (features, context) = BiometricPayloadBuilder.build(
              hrv: hrvVal, restingHR: restingVal, currentHR: currentVal,
              sleep: sleepVal, respiratory: respVal, bloodOxygen: o2Val, wristTemp: tempVal
          )

          let classification = inference.classify(features: features)

          do {
              let glooResponse = try await glooService.fetchVerse(
                  for: classification, biometricContext: context, preferences: preferences
              )
              let verse = try await youVersion.fetchVerse(
                  reference: glooResponse.verseReference,
                  versionId: versionId(for: preferences.translation)
              )
              let finalVerse = ScriptureVerse(
                  reference: verse.reference,
                  displayLabel: verse.displayLabel,
                  text: verse.text,
                  translation: verse.translation,
                  reflection: glooResponse.reflection,
                  deliveredAt: Date(),
                  emotionalContext: classification.state.rawValue
              )
              cache.store(verse: finalVerse)
              currentVerse = finalVerse
          } catch {
              // Silently fail — never surface errors to the user
          }
      }

      private func versionId(for translation: String) -> Int {
          // Common YouVersion version IDs — expand after July 6 with full list from API
          switch translation {
          case "NIV": return 111
          case "ESV": return 59
          case "NLT": return 116
          case "KJV": return 1
          case "MSG": return 97
          default:    return 111
          }
      }
  }
  ```

- [ ] **Step 2: Wire `VerseOrchestrator` into `PulseApp.swift`**

  ```swift
  import SwiftUI

  @main
  struct PulseApp: App {
      @StateObject private var orchestrator = VerseOrchestrator(
          glooService: GlooAPIService(apiKey: Secrets.glooAPIKey),
          youVersion: YouVersionAPIService(apiKey: Secrets.youVersionAPIKey),
          preferences: .init(translation: "NIV", language: "en")
      )

      var body: some Scene {
          WindowGroup {
              // OnboardingView added in Task 13 — use SettingsView as root until then
              SettingsView()
                  .environmentObject(orchestrator)
          }
      }
  }

  // Secrets.swift — add to .gitignore, never commit
  enum Secrets {
      static let glooAPIKey = "YOUR_GLOO_API_KEY"
      static let youVersionAPIKey = "YOUR_YOUVERSION_API_KEY"
  }
  ```

- [ ] **Step 3: Add `Secrets.swift` to `.gitignore`**

  Create `.gitignore` if not present:
  ```
  Pulse/Secrets.swift
  *.xcuserstate
  .DS_Store
  ```

  Create `Pulse/Secrets.swift` locally (never committed):
  ```swift
  enum Secrets {
      static let glooAPIKey = "REPLACE_WITH_REAL_KEY"
      static let youVersionAPIKey = "REPLACE_WITH_REAL_KEY"
  }
  ```

- [ ] **Step 4: Manual device test — verify pipeline fires end-to-end**

  Run on a real iPhone paired with Apple Watch. Grant all HealthKit permissions in the prompt flow. Call `orchestrator.run()` from a debug button in `OnboardingView`. Confirm in the console that Gloo and YouVersion calls succeed (use real API keys from competition).

- [ ] **Step 5: Commit**

  ```bash
  git add Pulse/VerseOrchestrator.swift Pulse/PulseApp.swift .gitignore
  git commit -m "feat: VerseOrchestrator wires full pipeline end-to-end"
  ```

---

## Task 10: WatchConnectivity (iOS → watchOS)

**Files:**
- Create: `Pulse/Connectivity/PhoneSessionManager.swift`
- Create: `PulseWatch/Connectivity/WatchSessionManager.swift`

**Interfaces:**
- Consumes: `SharedVerse` (Task 1); `VerseCache.currentSharedVerse` (Task 7)
- Produces: `PhoneSessionManager.sendVerse(_:SharedVerse)` — pushes to watch via `updateApplicationContext`

- [ ] **Step 1: Create `PhoneSessionManager.swift`**

  ```swift
  import WatchConnectivity

  final class PhoneSessionManager: NSObject, WCSessionDelegate {
      static let shared = PhoneSessionManager()

      private override init() {
          super.init()
          if WCSession.isSupported() {
              WCSession.default.delegate = self
              WCSession.default.activate()
          }
      }

      func sendVerse(_ verse: SharedVerse) {
          guard WCSession.default.activationState == .activated else { return }
          try? WCSession.default.updateApplicationContext(verse.toDictionary())
      }

      func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
      func sessionDidBecomeInactive(_ session: WCSession) {}
      func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
  }
  ```

- [ ] **Step 2: Call `sendVerse` from `VerseOrchestrator` after storing**

  In `VerseOrchestrator.run()`, after `cache.store(verse: finalVerse)`:
  ```swift
  if let shared = cache.currentSharedVerse {
      PhoneSessionManager.shared.sendVerse(shared)
  }
  ```

- [ ] **Step 3: Create `WatchSessionManager.swift`**

  ```swift
  import WatchConnectivity
  import Combine

  final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
      static let shared = WatchSessionManager()
      @Published var currentVerse: SharedVerse?

      private override init() {
          super.init()
          if WCSession.isSupported() {
              WCSession.default.delegate = self
              WCSession.default.activate()
          }
      }

      func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
          if let verse = SharedVerse.from(dictionary: context) {
              DispatchQueue.main.async { self.currentVerse = verse }
          }
      }

      func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
  }
  ```

- [ ] **Step 4: Activate in `PulseWatchApp.swift`**

  ```swift
  import SwiftUI

  @main
  struct PulseWatchApp: App {
      @StateObject private var sessionManager = WatchSessionManager.shared

      var body: some Scene {
          WindowGroup {
              VerseFullView()
                  .environmentObject(sessionManager)
          }
      }
  }
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add Pulse/Connectivity/PhoneSessionManager.swift PulseWatch/Connectivity/WatchSessionManager.swift PulseWatch/PulseWatchApp.swift
  git commit -m "feat: WatchConnectivity bridge for verse delivery"
  ```

---

## Task 11: WidgetKit Complication

**Files:**
- Create: `PulseWatch/Complications/VerseWidget.swift`

**Interfaces:**
- Consumes: `SharedVerse` (Task 1); `WatchSessionManager.currentVerse` (Task 10)
- Produces: WidgetKit complication in Modular Large + Graphic Rectangular families

- [ ] **Step 1: Add a Watch Widget Extension target**

  File → New → Target → Widget Extension. Name: `PulseWatchWidget`. Check "Include Configuration Intent": No. Set the deployment target to watchOS 10.0.

  This gives the widget its own `@main` entry point, separate from `PulseWatchApp`'s `@main`. Add the same App Group (`group.com.YOURTEAM.pulse`) to this target in Signing & Capabilities.

- [ ] **Step 2: Create `VerseWidget.swift`**

  ```swift
  import WidgetKit
  import SwiftUI

  struct VerseEntry: TimelineEntry {
      let date: Date
      let verse: SharedVerse?
  }

  struct VerseTimelineProvider: TimelineProvider {
      func placeholder(in context: Context) -> VerseEntry {
          VerseEntry(date: Date(), verse: SharedVerse(
              reference: "PSA.4.8", displayLabel: "Psalm 4:8",
              text: "In peace I will lie down and sleep.",
              reflection: nil, deliveredAt: Date()
          ))
      }

      func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
          completion(VerseEntry(date: Date(), verse: loadCachedVerse()))
      }

      func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
          let entry = VerseEntry(date: Date(), verse: loadCachedVerse())
          completion(Timeline(entries: [entry], policy: .never))
      }

      private func loadCachedVerse() -> SharedVerse? {
          guard let data = UserDefaults(suiteName: "group.com.YOURTEAM.pulse")?.data(forKey: SharedVerse.watchContextKey),
                let verse = try? JSONDecoder().decode(SharedVerse.self, from: data) else { return nil }
          return verse
      }
  }

  struct VerseWidgetView: View {
      var entry: VerseEntry
      @Environment(\.widgetFamily) var family

      var body: some View {
          if let verse = entry.verse {
              VStack(alignment: .leading, spacing: 4) {
                  Text(verse.text)
                      .font(family == .accessoryRectangular ? .caption2 : .caption)
                      .lineLimit(family == .accessoryRectangular ? 2 : 4)
                  Text(verse.displayLabel)
                      .font(.system(size: 9))
                      .foregroundStyle(.secondary)
              }
              .padding(4)
          } else {
              Text("Pulse")
                  .font(.caption)
                  .foregroundStyle(.secondary)
          }
      }
  }

  struct VerseWidget: Widget {
      var body: some WidgetConfiguration {
          StaticConfiguration(kind: "PulseVerseWidget", provider: VerseTimelineProvider()) { entry in
              VerseWidgetView(entry: entry)
          }
          .configurationDisplayName("Pulse")
          .description("Scripture at the right moment.")
          .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
      }
  }

  @main
  struct PulseWatchWidgetBundle: WidgetBundle {
      var body: some Widget {
          VerseWidget()
      }
  }
  ```

- [ ] **Step 3: Add App Group capability**

  Both `Pulse` (iOS) and `PulseWatch` targets need the same App Group: `group.com.YOURTEAM.pulse`. Add via Signing & Capabilities → App Groups.

  Update `WatchSessionManager` to cache the verse in the shared group UserDefaults:
  ```swift
  func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
      if let verse = SharedVerse.from(dictionary: context) {
          DispatchQueue.main.async { self.currentVerse = verse }
          // Cache for widget
          if let data = try? JSONEncoder().encode(verse) {
              UserDefaults(suiteName: "group.com.YOURTEAM.pulse")?.set(data, forKey: SharedVerse.watchContextKey)
          }
          WidgetCenter.shared.reloadAllTimelines()
      }
  }
  ```

- [ ] **Step 4: Build and run on Apple Watch — add complication to watch face**

  Run the `PulseWatch` scheme on a real watch. Long-press the watch face → Edit → Complications → find "Pulse" → assign to a slot. Trigger a verse delivery from the iPhone debug button and confirm the complication updates.

- [ ] **Step 5: Commit**

  ```bash
  git add PulseWatch/Complications/VerseWidget.swift
  git commit -m "feat: WidgetKit complication displays verse on watch face"
  ```

---

## Task 12: watchOS Views (Full-Screen + Morning)

**Files:**
- Create: `PulseWatch/Views/VerseFullView.swift`
- Create: `PulseWatch/Views/MorningView.swift`

**Interfaces:**
- Consumes: `WatchSessionManager.currentVerse` (Task 10)
- Produces: Two SwiftUI views shown on the watch

- [ ] **Step 1: Create `VerseFullView.swift`**

  ```swift
  import SwiftUI
  import WatchKit

  struct VerseFullView: View {
      @EnvironmentObject var session: WatchSessionManager

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 8) {
                  if let verse = session.currentVerse {
                      Text(verse.text)
                          .font(.body)
                          .multilineTextAlignment(.leading)
                      Text(verse.displayLabel)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      if let reflection = verse.reflection {
                          Divider()
                          Text(reflection)
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                              .multilineTextAlignment(.leading)
                      }
                  } else {
                      Text("Pulse is learning your rhythms.")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                  }
              }
              .padding(.horizontal, 4)
          }
          .onTapGesture {
              WKInterfaceDevice.current().play(.click)
          }
      }
  }
  ```

- [ ] **Step 2: Create `MorningView.swift`**

  ```swift
  import SwiftUI
  import WatchKit

  struct MorningView: View {
      @EnvironmentObject var session: WatchSessionManager
      @State private var appeared = false

      var body: some View {
          VStack(spacing: 6) {
              if let verse = session.currentVerse {
                  Text(verse.text)
                      .font(.caption)
                      .multilineTextAlignment(.center)
                  Text(verse.displayLabel)
                      .font(.system(size: 10))
                      .foregroundStyle(.secondary)
              }
          }
          .padding(6)
          .onAppear {
              guard !appeared else { return }
              appeared = true
              // Morning is the only moment Pulse initiates a haptic
              WKInterfaceDevice.current().play(.notification)
          }
      }
  }
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add PulseWatch/Views/VerseFullView.swift PulseWatch/Views/MorningView.swift
  git commit -m "feat: watchOS full-screen verse view and morning view"
  ```

---

## Task 13: iOS Onboarding + Settings

**Files:**
- Create: `Pulse/Views/OnboardingView.swift`
- Create: `Pulse/Views/SettingsView.swift`

- [ ] **Step 1: Create `OnboardingView.swift`**

  ```swift
  import SwiftUI
  import HealthKit

  struct OnboardingView: View {
      @EnvironmentObject var orchestrator: VerseOrchestrator
      @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
      @State private var step = 0

      var body: some View {
          if hasCompletedOnboarding {
              SettingsView()
          } else {
              TabView(selection: $step) {
                  welcomeStep.tag(0)
                  permissionsStep.tag(1)
                  translationStep.tag(2)
              }
              .tabViewStyle(.page)
          }
      }

      private var welcomeStep: some View {
          VStack(spacing: 20) {
              Text("Pulse")
                  .font(.largeTitle.bold())
              Text("The right word at the right physiological moment.")
                  .multilineTextAlignment(.center)
                  .foregroundStyle(.secondary)
              Button("Get Started") { step = 1 }
                  .buttonStyle(.borderedProminent)
          }
          .padding()
      }

      private var permissionsStep: some View {
          VStack(spacing: 16) {
              Text("Pulse reads your heart rate, HRV, and sleep data to understand how you're feeling.")
                  .multilineTextAlignment(.center)
              Text("Your health data never leaves your device.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              Button("Allow Health Access") {
                  Task {
                      try? await HealthKitManager().requestAuthorization()
                      step = 2
                  }
              }
              .buttonStyle(.borderedProminent)
          }
          .padding()
      }

      private var translationStep: some View {
          VStack(spacing: 16) {
              Text("Which Bible translation do you prefer?")
              Picker("Translation", selection: .constant("NIV")) {
                  ForEach(["NIV", "ESV", "NLT", "KJV", "MSG"], id: \.self) { Text($0) }
              }
              Button("Start Listening") {
                  hasCompletedOnboarding = true
                  Task { await orchestrator.run() }
              }
              .buttonStyle(.borderedProminent)
          }
          .padding()
      }
  }
  ```

- [ ] **Step 2: Create `SettingsView.swift`**

  ```swift
  import SwiftUI

  struct SettingsView: View {
      @EnvironmentObject var orchestrator: VerseOrchestrator
      @AppStorage("preferredTranslation") private var translation = "NIV"

      var body: some View {
          NavigationStack {
              List {
                  Section("Current Verse") {
                      if let verse = orchestrator.currentVerse {
                          VStack(alignment: .leading, spacing: 4) {
                              Text(verse.text).font(.callout)
                              Text(verse.displayLabel).font(.caption).foregroundStyle(.secondary)
                          }
                      } else {
                          Text("No verse yet — Pulse is listening.")
                              .foregroundStyle(.secondary)
                      }
                  }

                  Section("Preferences") {
                      Picker("Translation", selection: $translation) {
                          ForEach(["NIV", "ESV", "NLT", "KJV", "MSG"], id: \.self) { Text($0) }
                      }
                  }

                  Section("Debug") {
                      Button("Trigger verse now") {
                          Task { await orchestrator.run() }
                      }
                  }
              }
              .navigationTitle("Pulse")
          }
      }
  }
  ```

- [ ] **Step 3: Update `PulseApp.swift` to use `OnboardingView` as root**

  In `Pulse/PulseApp.swift`, change:
  ```swift
  // OnboardingView added in Task 13 — use SettingsView as root until then
  SettingsView()
      .environmentObject(orchestrator)
  ```
  to:
  ```swift
  OnboardingView()
      .environmentObject(orchestrator)
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add Pulse/Views/OnboardingView.swift Pulse/Views/SettingsView.swift Pulse/PulseApp.swift
  git commit -m "feat: onboarding flow and settings view"
  ```

---

## Task 14: Background Delivery + HealthKit Observer

Connect `HealthKitManager.enableBackgroundDelivery` so the pipeline fires automatically when the watch writes new HRV data, even when the app is in the background.

**Files:**
- Modify: `Pulse/PulseApp.swift`
- Modify: `Pulse/VerseOrchestrator.swift`

- [ ] **Step 1: Start background delivery from app launch**

  In `PulseApp.swift`, add after `@StateObject`:
  ```swift
  .onAppear {
      orchestrator.startBackgroundObservation()
  }
  ```

- [ ] **Step 2: Add `startBackgroundObservation` to `VerseOrchestrator`**

  ```swift
  func startBackgroundObservation() {
      hkManager.enableBackgroundDelivery {
          Task { await self.run() }
      }
  }
  ```

- [ ] **Step 3: Register background app refresh task in Info.plist**

  ```xml
  <key>BGTaskSchedulerPermittedIdentifiers</key>
  <array>
      <string>com.YOURTEAM.pulse.refresh</string>
  </array>
  ```

- [ ] **Step 4: Build and test on device**

  Lock your iPhone. Let the Apple Watch collect data overnight. In the morning, confirm the complication has updated. Check the HealthKit background delivery logs via Instruments if needed.

- [ ] **Step 5: Commit**

  ```bash
  git add Pulse/PulseApp.swift Pulse/VerseOrchestrator.swift Pulse/Info.plist
  git commit -m "feat: background HealthKit delivery wakes pipeline automatically"
  ```

---

## Task 15: TestFlight + GitHub Cleanup

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

  ```markdown
  # Pulse

  Scripture at the right physiological moment.

  ## What it does
  Pulse monitors Apple Watch biometrics (HRV, heart rate, sleep quality) and delivers a
  Bible verse silently to your watch face when it detects a moment that matters — 3am
  wakefulness, post-workout exhaustion, sustained stress. No notification. No schedule.
  Just presence when you raise your wrist.

  ## APIs Used
  - **YouVersion Platform API** — verse text in 2,000+ languages and translations
  - **Gloo AI Studio API** — faith-tuned verse selection based on classified emotional state

  ## Setup
  1. Clone this repo
  2. Open `pulse-scripture.xcodeproj`
  3. Set your Team in Signing & Capabilities for both targets
  4. Create `Pulse/Secrets.swift` (not committed):
     ```swift
     enum Secrets {
         static let glooAPIKey = "YOUR_KEY"
         static let youVersionAPIKey = "YOUR_KEY"
     }
     ```
  5. Set App Group to `group.com.YOURTEAM.pulse` in both targets
  6. Run on iPhone + paired Apple Watch

  ## Architecture
  See `docs/superpowers/specs/2026-06-30-pulse-design.md`
  ```

- [ ] **Step 2: Archive and upload to TestFlight**

  Product → Archive → Distribute App → TestFlight → upload. Create a Public Link in App Store Connect: TestFlight → your build → Public Link → enable. Copy the link for the Kaggle submission.

- [ ] **Step 3: Commit and tag**

  ```bash
  git add README.md
  git commit -m "docs: README with setup instructions for judges"
  git tag v1.0.0-competition
  git push origin main --tags
  ```

---

## Task 16: Kaggle Notebook (Python — parallel workstream)

> This task can run in parallel with Tasks 5–15. It documents the model training pipeline and demonstrates both APIs end-to-end in Python for the judges.

**Files:**
- Create: `pulse-notebook.ipynb`

- [ ] **Step 1: Create notebook with these sections**

  **Section 1 — Problem & Architecture** (Markdown): explain the pipeline diagram, both APIs, the privacy model.

  **Section 2 — Data: Synthetic training data generation**
  ```python
  import numpy as np
  import pandas as pd

  np.random.seed(42)
  n = 500

  # Clinically-derived ranges per state (Thayer & Lane 2000, Kim et al. 2018)
  states = {
      'sleepless':   dict(hrv=(14,22),  hr_delta=(15,30), eff=(0.4,0.65), deep=(0.05,0.12), rem=(0.08,0.15), wake=1.0),
      'anxious':     dict(hrv=(15,25),  hr_delta=(18,35), eff=(0.6,0.80), deep=(0.10,0.18), rem=(0.15,0.22), wake=0.0),
      'depleted':    dict(hrv=(12,20),  hr_delta=(5,15),  eff=(0.50,0.70), deep=(0.05,0.10), rem=(0.10,0.18), wake=0.0),
      'struggling':  dict(hrv=(14,22),  hr_delta=(8,18),  eff=(0.55,0.72), deep=(0.08,0.14), rem=(0.12,0.20), wake=0.1),
      'recovering':  dict(hrv=(25,40),  hr_delta=(5,15),  eff=(0.70,0.88), deep=(0.15,0.22), rem=(0.18,0.25), wake=0.0),
      'restful':     dict(hrv=(45,70),  hr_delta=(0,5),   eff=(0.80,0.95), deep=(0.18,0.25), rem=(0.20,0.28), wake=0.0),
      'resilient':   dict(hrv=(35,55),  hr_delta=(8,20),  eff=(0.72,0.88), deep=(0.15,0.22), rem=(0.18,0.26), wake=0.0),
      'unknown':     dict(hrv=(20,40),  hr_delta=(0,10),  eff=(0.65,0.80), deep=(0.12,0.18), rem=(0.15,0.22), wake=0.0),
  }

  rows = []
  for state, params in states.items():
      for _ in range(n // len(states)):
          hour = np.random.randint(0, 24)
          angle = 2 * np.pi * hour / 24
          rows.append({
              'hrv_sdnn': np.random.uniform(*params['hrv']),
              'hrv_7day_slope': np.random.uniform(-0.5, 0.5),
              'hr_delta_from_resting': np.random.uniform(*params['hr_delta']),
              'sleep_efficiency': np.random.uniform(*params['eff']),
              'deep_sleep_pct': np.random.uniform(*params['deep']),
              'rem_pct': np.random.uniform(*params['rem']),
              'awakening_count': np.random.uniform(0, 5),
              'late_night_wakefulness': float(np.random.random() < params['wake']),
              'respiratory_rate': np.random.uniform(12, 22),
              'blood_oxygen': np.random.uniform(94, 99),
              'wrist_temp_delta': np.random.uniform(-0.5, 0.5),
              'time_of_day_sin': np.sin(angle),
              'time_of_day_cos': np.cos(angle),
              'label': state,
          })

  df = pd.DataFrame(rows)
  print(df['label'].value_counts())
  ```

  **Section 3 — Model Training**
  ```python
  from sklearn.ensemble import RandomForestClassifier
  from sklearn.model_selection import train_test_split
  from sklearn.metrics import classification_report, ConfusionMatrixDisplay
  import matplotlib.pyplot as plt

  feature_cols = [c for c in df.columns if c != 'label']
  X, y = df[feature_cols], df['label']
  X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, stratify=y, random_state=42)

  model = RandomForestClassifier(n_estimators=100, max_depth=8, random_state=42)
  model.fit(X_train, y_train)

  print(classification_report(y_test, model.predict(X_test)))
  ConfusionMatrixDisplay.from_estimator(model, X_test, y_test, xticks_rotation=45)
  plt.tight_layout()
  plt.show()
  ```

  **Section 4 — CoreML Export**
  ```python
  import coremltools as ct

  coreml_model = ct.converters.sklearn.convert(model, feature_cols, 'emotionalState')
  coreml_model.short_description = 'Pulse emotion classifier v1'
  coreml_model.save('PulseEmotionClassifier.mlmodel')
  print("Saved PulseEmotionClassifier.mlmodel")
  ```

  **Section 5 — Gloo AI API Demo**
  ```python
  import requests

  GLOO_API_KEY = "YOUR_GLOO_KEY"  # replace before running
  GLOO_BASE = "https://api.gloo.ai/v1"  # update after July 6

  payload = {
      "emotional_state": "sleepless",
      "state_confidence": 0.89,
      "supporting_signals": {
          "hrv_sdnn_ms": 17.0,
          "hr_delta_bpm": 22,
          "late_night_wake": True,
          "sleep_efficiency": 0.61,
          "hrv_trend": "declining"
      },
      "time_context": {"time_of_day": "03:22", "day_of_week": "Tuesday"},
      "user_preferences": {"translation": "NIV", "language": "en"}
  }

  response = requests.post(
      f"{GLOO_BASE}/scripture/verse",
      json=payload,
      headers={"Authorization": f"Bearer {GLOO_API_KEY}"}
  )
  gloo_data = response.json()
  print("Gloo response:", gloo_data)
  verse_ref = gloo_data["verseReference"]
  ```

  **Section 6 — YouVersion API Demo**
  ```python
  YV_API_KEY = "YOUR_YV_KEY"  # replace before running
  YV_BASE = "https://api.youversion.com/v1"  # update after July 6

  yv_response = requests.get(
      f"{YV_BASE}/bible/verse/111/{verse_ref}",
      headers={"X-API-Key": YV_API_KEY}
  )
  yv_data = yv_response.json()
  print(f"\n{yv_data['data']['reference']}")
  print(yv_data['data']['content'])
  ```

  **Section 7 — End-to-End Summary** (Markdown): show the full pipeline in one diagram, credit both APIs, link to GitHub repo.

- [ ] **Step 2: Run all cells top to bottom — confirm no errors**

  All cells must produce output. API cells will need real keys from July 6.

- [ ] **Step 3: Make notebook public on Kaggle and attach to writeup**

- [ ] **Step 4: Commit**

  ```bash
  git add pulse-notebook.ipynb
  git commit -m "feat: Kaggle notebook with model training and API demo"
  ```

---

## Final Submission Checklist

- [ ] Public GitHub repo with MIT license, clean README, Secrets.swift in .gitignore
- [ ] Kaggle notebook public, all cells run, both APIs demonstrated
- [ ] YouTube video ≤3 minutes, publicly accessible, no login required
- [ ] TestFlight public link (or GitHub repo link as fallback)
- [ ] Kaggle writeup submitted (≤500 words), video and notebook attached, cover image uploaded
- [ ] Both Gloo AI and YouVersion APIs visibly used in code and notebook
- [ ] Partner's CoreML model integrated and `EmotionInferenceService` stub replaced
