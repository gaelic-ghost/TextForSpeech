import Foundation
import Observation

// MARK: - Runtime

public extension TextForSpeech {
    @Observable
    final class Runtime {
        internal enum Versioning {
            static let currentPersistedStateVersion = 1
        }

        public let persistenceURL: URL
        public var builtInStyle: TextForSpeech.BuiltInProfileStyle

        internal let fileManager: FileManager

        internal var activeCustomProfileID: String
        internal var storedCustomProfilesByID: [String: TextForSpeech.Profile]

        public init(
            builtInStyle: TextForSpeech.BuiltInProfileStyle = .balanced,
            persistenceURL: URL? = nil,
            fileManager: FileManager = .default,
            bundle: Bundle = .main
        ) throws {
            self.builtInStyle = builtInStyle
            self.fileManager = fileManager
            self.persistenceURL = persistenceURL?.standardizedFileURL
                ?? Self.defaultPersistenceURL(bundle: bundle)
            activeCustomProfileID = TextForSpeech.Profile.default.id
            storedCustomProfilesByID = [:]

            try loadPersistedStateIfPresent()
            try repairProfileState(persistIfChanged: true)
        }

        public var baseProfile: TextForSpeech.Profile {
            .builtInBase(style: builtInStyle)
        }
    }
}

// MARK: - Runtime Accessors

public extension TextForSpeech.Runtime {
    var profiles: Profiles {
        Profiles(runtime: self)
    }

    var persistence: Persistence {
        Persistence(runtime: self)
    }

    static func defaultPersistenceURL(bundle: Bundle = .main) -> URL {
        defaultPersistenceURL(bundleIdentifier: bundle.bundleIdentifier)
    }
}
