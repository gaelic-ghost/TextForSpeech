import Foundation
import Observation

public extension TextForSpeech {
    @Observable
    final class Runtime {
        public enum PersistenceConfiguration: Sendable {
            case `default`
            case file(URL)
        }

        enum Versioning {
            static let currentPersistedStateVersion = 1
        }

        public let persistenceConfiguration: PersistenceConfiguration
        public internal(set) var builtInStyle: TextForSpeech.BuiltInProfileStyle
        public internal(set) var activeSummarizationProvider: TextForSpeech.SummarizationProvider

        let fileManager: FileManager
        let persistenceURL: URL

        var activeCustomProfileID: String
        var storedCustomProfilesByID: [String: TextForSpeech.Profile]

        public var baseProfile: TextForSpeech.Profile {
            .builtInBase(style: builtInStyle)
        }

        public init(
            builtInStyle: TextForSpeech.BuiltInProfileStyle = .balanced,
            persistence: PersistenceConfiguration = .default,
            fileManager: FileManager = .default,
            bundle: Bundle = .main,
        ) throws {
            self.builtInStyle = builtInStyle
            activeSummarizationProvider = .foundationModels
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
    }
}

// MARK: - Runtime Accessors

public extension TextForSpeech.Runtime {
    var profiles: Profiles {
        Profiles(runtime: self)
    }

    var style: Style {
        Style(runtime: self)
    }

    var summarizationProvider: SummarizationProviderSettings {
        SummarizationProviderSettings(runtime: self)
    }

    var normalize: Normalization {
        Normalization(runtime: self)
    }

    var persistence: Persistence {
        Persistence(runtime: self)
    }

    static func defaultPersistenceURL(bundle: Bundle = .main) -> URL {
        defaultPersistenceURL(bundleIdentifier: bundle.bundleIdentifier)
    }
}
