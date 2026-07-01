// PulseTests/VerseOrchestratorTests.swift
import XCTest
@testable import Pulse

@MainActor
final class VerseOrchestratorTests: XCTestCase {

    // MARK: - Test fixtures

    private var mockHK: MockHealthKitManager!
    private var mockGloo: MockGlooAPIService!
    private var mockYouVersion: MockYouVersionAPIService!
    private var mockCache: MockVerseCache!
    private var mockTrigger: MockTriggerDetector!
    private var mockInference: MockEmotionInferenceService!

    override func setUp() {
        super.setUp()
        mockHK         = MockHealthKitManager()
        mockGloo       = MockGlooAPIService()
        mockYouVersion = MockYouVersionAPIService()
        mockCache      = MockVerseCache()
        mockTrigger    = MockTriggerDetector()
        mockInference  = MockEmotionInferenceService()

        // Happy-path defaults
        mockTrigger.stubbedReason = .fallback24Hour
        mockGloo.stubbedResponse = GlooResponse(
            scriptureTheme: "peace_in_sleeplessness",
            verseReference: "PSA.4.8",
            verseDisplayLabel: "Psalm 4:8",
            reflection: "You are held."
        )
        mockYouVersion.stubbedVerse = ScriptureVerse(
            reference: "PSA.4.8",
            displayLabel: "Psalm 4:8",
            text: "In peace I will lie down and sleep.",
            translation: "NIV",
            reflection: nil,
            deliveredAt: Date(),
            emotionalContext: ""
        )
    }

    override func tearDown() {
        mockHK         = nil
        mockGloo       = nil
        mockYouVersion = nil
        mockCache      = nil
        mockTrigger    = nil
        mockInference  = nil
        super.tearDown()
    }

    private func makeSUT(
        preferences: GlooRequest.UserPreferences = .init(translation: "NIV", language: "en")
    ) -> VerseOrchestrator {
        // All dependencies injected explicitly — no @MainActor defaults required.
        VerseOrchestrator(
            hkManager:   mockHK,
            inference:   mockInference,
            glooService:  mockGloo,
            youVersion:   mockYouVersion,
            cache:        mockCache,
            trigger:      mockTrigger,
            preferences:  preferences
        )
    }

    // MARK: - canDeliver guard

    func test_run_skipsEntirePipeline_whenCacheCannotDeliver() async {
        mockCache.canDeliver = false
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockGloo.callCount, 0, "Gloo should not be called when canDeliver is false")
        XCTAssertNil(mockCache.storedVerse,  "No verse should be stored")
    }

    // MARK: - Trigger guard

    func test_run_skipsAPICall_whenNoTriggerFires() async {
        mockCache.canDeliver    = true
        mockTrigger.stubbedReason = nil   // no trigger fires
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockGloo.callCount, 0, "Gloo should not be called without a trigger")
        XCTAssertNil(mockCache.storedVerse, "No verse should be stored without a trigger")
    }

    // MARK: - Happy path

    func test_run_storesVerseAndPublishes_onSuccess() async {
        mockCache.canDeliver = true
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockGloo.callCount, 1)
        XCTAssertEqual(mockYouVersion.callCount, 1)
        XCTAssertNotNil(mockCache.storedVerse, "Verse should be stored in cache")
        XCTAssertEqual(mockCache.storedVerse?.reference, "PSA.4.8")
        XCTAssertEqual(sut.currentVerse?.reference, "PSA.4.8")
    }

    func test_run_attachesGlooReflectionToFinalVerse() async {
        mockCache.canDeliver = true
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockCache.storedVerse?.reflection, "You are held.")
    }

    func test_run_setsEmotionalContextFromClassification() async {
        mockCache.canDeliver = true
        let sut = makeSUT()

        await sut.run()

        XCTAssertFalse(
            mockCache.storedVerse?.emotionalContext.isEmpty ?? true,
            "emotionalContext should be a non-empty EmotionalState rawValue"
        )
    }

    // MARK: - Error handling

    func test_run_silentlyFailsWhenGlooThrows() async {
        mockCache.canDeliver  = true
        mockGloo.stubbedError = GlooAPIService.APIError.httpError(500)
        let sut = makeSUT()

        // Must not throw — orchestrator must swallow all errors.
        await sut.run()

        XCTAssertNil(mockCache.storedVerse, "No verse stored on Gloo error")
        XCTAssertNil(sut.currentVerse,      "currentVerse stays nil on error")
    }

    func test_run_silentlyFailsWhenYouVersionThrows() async {
        mockCache.canDeliver       = true
        mockYouVersion.stubbedError = YouVersionAPIService.APIError.httpError(404)
        let sut = makeSUT()

        await sut.run()

        XCTAssertNil(mockCache.storedVerse, "No verse stored on YouVersion error")
    }

    // MARK: - 24-hour fallback trigger

    func test_run_fetchesVerse_whenFallback24HourTriggerFires() async {
        // Arrange: simulate 25 hours since last verse with fallback trigger active
        mockCache.canDeliver = true
        mockCache.hoursSinceLastVerse = 25
        mockTrigger.stubbedReason = .fallback24Hour
        let sut = makeSUT()

        // Act
        await sut.run()

        // Assert: Gloo was called once, meaning the fallback path completed
        XCTAssertEqual(mockGloo.callCount, 1, "Gloo should be called when fallback24Hour trigger fires")
        XCTAssertNotNil(mockCache.storedVerse, "Verse should be stored after fallback24Hour trigger")
    }

    // MARK: - versionId mapping

    func test_run_routesThroughPipeline_forESVPreference() async {
        // Verifies that an ESV preference reaches YouVersion without crashing.
        // The exact versionId (59) is an implementation detail; observable effect
        // is that the pipeline completes and stores a verse.
        mockCache.canDeliver = true
        let sut = makeSUT(preferences: .init(translation: "ESV", language: "en"))

        await sut.run()

        XCTAssertEqual(mockYouVersion.callCount, 1)
        XCTAssertEqual(mockCache.storedVerse?.reference, "PSA.4.8")
    }

    func test_run_routesThroughPipeline_forUnknownTranslation() async {
        // Unknown translation falls back to NIV (versionId 111) — pipeline should succeed.
        mockCache.canDeliver = true
        let sut = makeSUT(preferences: .init(translation: "NRSV", language: "en"))

        await sut.run()

        XCTAssertEqual(mockYouVersion.callCount, 1)
    }
}
