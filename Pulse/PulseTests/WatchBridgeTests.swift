// PulseTests/WatchBridgeTests.swift
import XCTest
@testable import Pulse

/// Tests that VerseOrchestrator correctly drives the WatchBridgeProtocol dependency.
@MainActor
final class WatchBridgeTests: XCTestCase {

    // MARK: - Fixtures

    private var mockHK: MockHealthKitManager!
    private var mockGloo: MockGlooAPIService!
    private var mockYouVersion: MockYouVersionAPIService!
    private var mockCache: MockVerseCache!
    private var mockTrigger: MockTriggerDetector!
    private var mockInference: MockEmotionInferenceService!
    private var mockBridge: MockWatchBridge!

    override func setUp() {
        super.setUp()
        mockHK         = MockHealthKitManager()
        mockGloo       = MockGlooAPIService()
        mockYouVersion = MockYouVersionAPIService()
        mockCache      = MockVerseCache()
        mockTrigger    = MockTriggerDetector()
        mockInference  = MockEmotionInferenceService()
        mockBridge     = MockWatchBridge()

        mockTrigger.stubbedReason = .fallback24Hour
        mockGloo.stubbedResponse = GlooResponse(
            scriptureTheme: "peace",
            verseReference: "PSA.4.8",
            verseDisplayLabel: "Psalm 4:8",
            reflection: "Rest in Him."
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
        mockBridge     = nil
        super.tearDown()
    }

    private func makeSUT() -> VerseOrchestrator {
        VerseOrchestrator(
            hkManager:   mockHK,
            inference:   mockInference,
            glooService:  mockGloo,
            youVersion:   mockYouVersion,
            cache:        mockCache,
            trigger:      mockTrigger,
            preferences:  .init(translation: "NIV", language: "en"),
            watchBridge:  mockBridge
        )
    }

    // MARK: - Bridge called on success

    func test_run_sendsVerseToWatch_onHappyPath() async {
        mockCache.canDeliver = true
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockBridge.callCount, 1, "Bridge should be called exactly once after a successful pipeline run")
        XCTAssertEqual(mockBridge.sentVerses.first?.reference, "PSA.4.8")
    }

    func test_run_sendsReflectionToWatch() async {
        mockCache.canDeliver = true
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockBridge.sentVerses.first?.reflection, "Rest in Him.")
    }

    // MARK: - Bridge NOT called when pipeline short-circuits

    func test_run_doesNotSendToWatch_whenCannotDeliver() async {
        mockCache.canDeliver = false
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockBridge.callCount, 0, "Bridge must not be called when canDeliver is false")
    }

    func test_run_doesNotSendToWatch_whenNoTriggerFires() async {
        mockCache.canDeliver = true
        mockTrigger.stubbedReason = nil
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockBridge.callCount, 0, "Bridge must not be called without a trigger")
    }

    func test_run_doesNotSendToWatch_whenGlooThrows() async {
        mockCache.canDeliver  = true
        mockGloo.stubbedError = GlooAPIService.APIError.httpError(500)
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockBridge.callCount, 0, "Bridge must not be called on Gloo error")
    }

    func test_run_doesNotSendToWatch_whenYouVersionThrows() async {
        mockCache.canDeliver        = true
        mockYouVersion.stubbedError = YouVersionAPIService.APIError.httpError(404)
        let sut = makeSUT()

        await sut.run()

        XCTAssertEqual(mockBridge.callCount, 0, "Bridge must not be called on YouVersion error")
    }

    // MARK: - Nil bridge is safe

    func test_run_withNilBridge_doesNotCrash() async {
        mockCache.canDeliver = true
        let sut = VerseOrchestrator(
            hkManager:  mockHK,
            inference:  mockInference,
            glooService: mockGloo,
            youVersion:  mockYouVersion,
            cache:       mockCache,
            trigger:     mockTrigger,
            preferences: .init(translation: "NIV", language: "en"),
            watchBridge: nil
        )

        await sut.run()

        // Passes if no crash; verse still stored on iOS side
        XCTAssertNotNil(mockCache.storedVerse)
    }
}
