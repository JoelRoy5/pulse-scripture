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
