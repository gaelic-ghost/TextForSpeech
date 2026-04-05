import Foundation

// MARK: - Errors

public extension TextForSpeech {
    enum PersistenceError: Swift.Error, Sendable, Equatable, LocalizedError {
        case missingPersistenceURL
        case unsupportedPersistedStateVersion(Int)
        case couldNotRead(URL, String)
        case couldNotDecode(URL, String)
        case couldNotCreateDirectory(URL, String)
        case couldNotWrite(URL, String)

        public var errorDescription: String? {
            switch self {
            case .missingPersistenceURL:
                "TextForSpeech could not load or save profiles because no persistence URL was configured for this runtime."
            case .unsupportedPersistedStateVersion(let version):
                "TextForSpeech could not load the persisted profile state because archive version \(version) is not supported by this build."
            case .couldNotRead(let url, let details):
                "TextForSpeech could not read persisted profiles from '\(url.path)'. \(details)"
            case .couldNotDecode(let url, let details):
                "TextForSpeech could not decode persisted profiles from '\(url.path)'. \(details)"
            case .couldNotCreateDirectory(let url, let details):
                "TextForSpeech could not create the directory for persisted profiles at '\(url.path)'. \(details)"
            case .couldNotWrite(let url, let details):
                "TextForSpeech could not write persisted profiles to '\(url.path)'. \(details)"
            }
        }
    }

    enum RuntimeError: Swift.Error, Sendable, Equatable, LocalizedError {
        case profileAlreadyExists(String)
        case profileNotFound(String)
        case replacementNotFound(String, profileID: String)

        public var errorDescription: String? {
            switch self {
            case .profileAlreadyExists(let id):
                "TextForSpeech could not create profile '\(id)' because a stored profile with that identifier already exists."
            case .profileNotFound(let id):
                "TextForSpeech could not find a stored profile named '\(id)'."
            case .replacementNotFound(let replacementID, let profileID):
                "TextForSpeech could not find replacement '\(replacementID)' in profile '\(profileID)'."
            }
        }
    }
}
