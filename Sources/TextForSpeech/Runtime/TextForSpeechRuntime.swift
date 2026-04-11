import Foundation
import Observation

// MARK: - Runtime

public extension TextForSpeech {
    @Observable
    final class Runtime {
        internal enum Versioning {
            static let currentPersistedStateVersion = 1
        }

        public enum PersistenceConfiguration: Sendable {
            case `default`
            case file(URL)
        }

        public let persistenceConfiguration: PersistenceConfiguration
        public var builtInStyle: TextForSpeech.BuiltInProfileStyle

        internal let fileManager: FileManager
        internal let persistenceURL: URL

        internal var activeCustomProfileID: String
        internal var storedCustomProfilesByID: [String: TextForSpeech.Profile]

        public init(
            builtInStyle: TextForSpeech.BuiltInProfileStyle = .balanced,
            persistence: PersistenceConfiguration = .default,
            fileManager: FileManager = .default,
            bundle: Bundle = .main
        ) throws {
            self.builtInStyle = builtInStyle
            self.fileManager = fileManager
            persistenceConfiguration = persistence
            persistenceURL = switch persistence {
            case .default:
                Self.defaultPersistenceURL(bundle: bundle)
            case let .file(url):
                url.standardizedFileURL
            }
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
