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
