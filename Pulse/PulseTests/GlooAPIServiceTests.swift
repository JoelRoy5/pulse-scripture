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
