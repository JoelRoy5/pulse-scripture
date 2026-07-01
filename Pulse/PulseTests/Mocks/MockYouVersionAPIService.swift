// PulseTests/Mocks/MockYouVersionAPIService.swift
import Foundation
@testable import Pulse

final class MockYouVersionAPIService: YouVersionAPIServiceProtocol {
    var stubbedVerse: ScriptureVerse?
    var stubbedError: Error?
    var callCount = 0

    func fetchVerse(reference: String, versionId: Int) async throws -> ScriptureVerse {
        callCount += 1
        if let error = stubbedError { throw error }
        return stubbedVerse!
    }
}
