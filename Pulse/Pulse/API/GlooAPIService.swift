import Foundation

final class GlooAPIService {
    enum APIError: Error {
        case httpError(Int)
        case decodingError
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
        preferences: GlooRequest.UserPreferences
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
        let parsed: GlooResponse
        do {
            parsed = try decoder.decode(GlooResponse.self, from: data)
        } catch {
            throw APIError.decodingError
        }
        return parsed
    }

    private func buildRequest(
        classification: EmotionClassification,
        context: BiometricContext?,
        preferences: GlooRequest.UserPreferences
    ) -> GlooRequest {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let hour = Calendar.current.component(.hour, from: now)

        return GlooRequest(
            emotionalState: classification.state.rawValue,
            stateConfidence: classification.confidence,
            supportingSignals: GlooRequest.SupportingSignals(
                hrvSdnnMs: context?.hrvSdnn,
                hrDeltaBpm: context?.hrDelta,
                lateNightWake: (0...5).contains(hour) && (context?.hrDelta ?? 0) > 10,
                sleepEfficiency: context?.sleepEfficiency,
                hrvTrend: context?.hrvTrend
            ),
            timeContext: GlooRequest.TimeContext(
                timeOfDay: formatter.string(from: now),
                dayOfWeek: dayFormatter.string(from: now)
            ),
            userPreferences: preferences
        )
    }
}

struct BiometricContext {
    let hrvSdnn: Double?
    let hrDelta: Double?
    let sleepEfficiency: Double?
    let hrvTrend: String
}
