import Foundation

struct ScriptureVerse: Codable {
    let reference: String
    let displayLabel: String
    let text: String
    let translation: String
    let reflection: String?
    let deliveredAt: Date
    let emotionalContext: String
}
