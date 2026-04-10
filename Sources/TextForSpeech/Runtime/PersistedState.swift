// MARK: - Persistence

public extension TextForSpeech {
    struct PersistedState: Codable, Sendable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case version
            case builtInStyle
            case activeCustomProfileID
            case profiles
        }

        public let version: Int
        public let builtInStyle: TextForSpeech.BuiltInProfileStyle
        public let activeCustomProfileID: String
        public let profiles: [String: Profile]

        public init(
            version: Int = 1,
            builtInStyle: TextForSpeech.BuiltInProfileStyle = .balanced,
            activeCustomProfileID: String,
            profiles: [String: Profile]
        ) {
            self.version = version
            self.builtInStyle = builtInStyle
            self.activeCustomProfileID = activeCustomProfileID
            self.profiles = profiles
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decode(Int.self, forKey: .version)
            builtInStyle = try container.decodeIfPresent(
                TextForSpeech.BuiltInProfileStyle.self,
                forKey: .builtInStyle
            ) ?? .balanced
            activeCustomProfileID = try container.decode(String.self, forKey: .activeCustomProfileID)
            profiles = try container.decode([String: Profile].self, forKey: .profiles)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(version, forKey: .version)
            try container.encode(builtInStyle, forKey: .builtInStyle)
            try container.encode(activeCustomProfileID, forKey: .activeCustomProfileID)
            try container.encode(profiles, forKey: .profiles)
        }
    }
}
