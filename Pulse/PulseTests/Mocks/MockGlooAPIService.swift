// PulseTests/Mocks/MockGlooAPIService.swift
import Foundation
@testable import Pulse

final class MockGlooAPIService: GlooAPIServiceProtocol {
    var stubbedResponse: GlooResponse?
    var stubbedError: Error?
    var callCount = 0

    func fetchVerse(
        for classification: EmotionClassification,
        biometricContext: BiometricContext?,
        preferences: GlooRequest.UserPreferences
    ) async throws -> GlooResponse {
        callCount += 1
        if let error = stubbedError { throw error }
        guard let response = stubbedResponse else { throw CancellationError() }
        return response
    }
}
