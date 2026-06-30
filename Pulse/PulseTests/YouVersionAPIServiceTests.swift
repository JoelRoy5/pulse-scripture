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
