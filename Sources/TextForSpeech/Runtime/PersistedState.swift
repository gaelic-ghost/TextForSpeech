// MARK: - Persistence

public extension TextForSpeech {
    struct PersistedState: Codable, Sendable, Equatable {
        public let version: Int
        public let activeCustomProfileID: String
        public let profiles: [String: Profile]

        public init(
            version: Int = 1,
            activeCustomProfileID: String,
            profiles: [String: Profile]
        ) {
            self.version = version
            self.activeCustomProfileID = activeCustomProfileID
            self.profiles = profiles
        }
    }
}
