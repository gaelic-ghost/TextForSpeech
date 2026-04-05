// MARK: - Persistence

public extension TextForSpeech {
    struct PersistedState: Codable, Sendable, Equatable {
        public let version: Int
        public let customProfile: Profile
        public let profiles: [String: Profile]

        public init(
            version: Int = 1,
            customProfile: Profile,
            profiles: [String: Profile]
        ) {
            self.version = version
            self.customProfile = customProfile
            self.profiles = profiles
        }
    }
}
