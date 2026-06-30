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
