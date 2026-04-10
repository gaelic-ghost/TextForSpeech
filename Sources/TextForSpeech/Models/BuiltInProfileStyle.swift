// MARK: - Built-In Profile Style

public extension TextForSpeech {
    enum BuiltInProfileStyle: String, Codable, CaseIterable, Sendable, Hashable {
        case balanced
        case compact
        case explicit
    }
}
