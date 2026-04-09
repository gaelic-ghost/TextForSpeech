import Foundation
import Observation

// MARK: - Runtime

public extension TextForSpeech {
    @Observable
    final class Runtime {
        private enum Versioning {
            static let currentPersistedStateVersion = 1
        }

        public let baseProfile: TextForSpeech.Profile
        public let persistenceURL: URL

        private let fileManager: FileManager

        private var activeCustomProfileID: String
        private var storedCustomProfilesByID: [String: TextForSpeech.Profile]

        public init(
            persistenceURL: URL? = nil,
            fileManager: FileManager = .default,
            bundle: Bundle = .main
        ) throws {
            baseProfile = .base
            self.fileManager = fileManager
            self.persistenceURL = persistenceURL?.standardizedFileURL
                ?? Self.defaultPersistenceURL(bundle: bundle)
            activeCustomProfileID = TextForSpeech.Profile.default.id
            storedCustomProfilesByID = [:]

            try loadPersistedStateIfPresent()
            try repairProfileState(persistIfChanged: true)
        }
    }
}

public extension TextForSpeech.Runtime {
    struct Profiles {
        fileprivate let runtime: TextForSpeech.Runtime

        public var activeID: String {
            runtime.activeCustomProfileID
        }

        public func active() -> TextForSpeech.Profile {
            runtime.storedCustomProfilesByID[runtime.activeCustomProfileID]
                ?? .default
        }

        public func stored(id: String) -> TextForSpeech.Profile? {
            runtime.storedCustomProfilesByID[id]
        }

        public func list() -> [TextForSpeech.Profile] {
            runtime.storedCustomProfilesByID.values.sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }

        public func effective() -> TextForSpeech.Profile {
            runtime.baseProfile.merged(with: active())
        }

        public func effective(id: String) -> TextForSpeech.Profile? {
            stored(id: id).map { runtime.baseProfile.merged(with: $0) }
        }

        public func activate(id: String) throws {
            guard runtime.storedCustomProfilesByID[id] != nil else {
                throw TextForSpeech.RuntimeError.profileNotFound(id)
            }

            runtime.activeCustomProfileID = id
            try runtime.persistCurrentState()
        }

        public func store(_ profile: TextForSpeech.Profile) throws {
            runtime.storedCustomProfilesByID[profile.id] = profile
            try runtime.repairProfileState(persistIfChanged: true)
        }

        @discardableResult
        public func create(
            id: String,
            name: String,
            replacements: [TextForSpeech.Replacement] = []
        ) throws -> TextForSpeech.Profile {
            guard runtime.storedCustomProfilesByID[id] == nil else {
                throw TextForSpeech.RuntimeError.profileAlreadyExists(id)
            }

            let profile = TextForSpeech.Profile(
                id: id,
                name: name,
                replacements: replacements
            )
            runtime.storedCustomProfilesByID[id] = profile
            try runtime.persistCurrentState()
            return profile
        }

        public func delete(id: String) throws {
            runtime.storedCustomProfilesByID.removeValue(forKey: id)
            try runtime.repairProfileState(persistIfChanged: true)
        }

        @discardableResult
        public func add(
            _ replacement: TextForSpeech.Replacement
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = active().adding(replacement)
            runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func add(
            _ replacement: TextForSpeech.Replacement,
            toProfileID id: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: id).adding(replacement)
            runtime.storedCustomProfilesByID[id] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func replace(
            _ replacement: TextForSpeech.Replacement
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try active().replacing(replacement)
            runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func replace(
            _ replacement: TextForSpeech.Replacement,
            inProfileID id: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: id).replacing(replacement)
            runtime.storedCustomProfilesByID[id] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func removeReplacement(
            id replacementID: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try active().removingReplacement(id: replacementID)
            runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func removeReplacement(
            id replacementID: String,
            fromProfileID profileID: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: profileID).removingReplacement(id: replacementID)
            runtime.storedCustomProfilesByID[profileID] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        public func reset() throws {
            runtime.activeCustomProfileID = TextForSpeech.Profile.default.id
            runtime.storedCustomProfilesByID[TextForSpeech.Profile.default.id] = .default
            try runtime.persistCurrentState()
        }

        private func storedProfile(id: String) throws -> TextForSpeech.Profile {
            guard let profile = runtime.storedCustomProfilesByID[id] else {
                throw TextForSpeech.RuntimeError.profileNotFound(id)
            }
            return profile
        }
    }

    struct Persistence {
        fileprivate let runtime: TextForSpeech.Runtime

        public var state: TextForSpeech.PersistedState {
            TextForSpeech.PersistedState(
                version: TextForSpeech.Runtime.Versioning.currentPersistedStateVersion,
                activeCustomProfileID: runtime.activeCustomProfileID,
                profiles: runtime.storedCustomProfilesByID
            )
        }

        public func restore(_ state: TextForSpeech.PersistedState) throws {
            guard state.version == TextForSpeech.Runtime.Versioning.currentPersistedStateVersion else {
                throw TextForSpeech.PersistenceError.unsupportedPersistedStateVersion(state.version)
            }

            runtime.activeCustomProfileID = state.activeCustomProfileID
            runtime.storedCustomProfilesByID = state.profiles
            try runtime.repairProfileState(persistIfChanged: false)
        }

        public func load() throws {
            try load(from: runtime.persistenceURL)
        }

        public func load(from url: URL) throws {
            let fileURL = url.standardizedFileURL
            guard runtime.fileManager.fileExists(atPath: fileURL.path) else { return }

            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch {
                throw TextForSpeech.PersistenceError.couldNotRead(
                    fileURL,
                    error.localizedDescription
                )
            }

            let state: TextForSpeech.PersistedState
            do {
                state = try JSONDecoder().decode(TextForSpeech.PersistedState.self, from: data)
            } catch {
                throw TextForSpeech.PersistenceError.couldNotDecode(
                    fileURL,
                    error.localizedDescription
                )
            }

            try restore(state)
        }

        public func save() throws {
            try save(to: runtime.persistenceURL)
        }

        public func save(to url: URL) throws {
            let fileURL = url.standardizedFileURL
            let directoryURL = fileURL.deletingLastPathComponent()

            do {
                try runtime.fileManager.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )
            } catch {
                throw TextForSpeech.PersistenceError.couldNotCreateDirectory(
                    directoryURL,
                    error.localizedDescription
                )
            }

            let data: Data
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                data = try encoder.encode(state)
            } catch {
                throw TextForSpeech.PersistenceError.couldNotWrite(
                    fileURL,
                    "TextForSpeech could not encode the current profile state before writing it. \(error.localizedDescription)"
                )
            }

            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                throw TextForSpeech.PersistenceError.couldNotWrite(
                    fileURL,
                    error.localizedDescription
                )
            }
        }
    }

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

private extension TextForSpeech.Runtime {
    static func defaultPersistenceURL(bundleIdentifier: String?) -> URL {
        let namespace = bundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? "TextForSpeech"
        let namespacedDirectory = URL.applicationSupportDirectory
            .appending(path: namespace, directoryHint: .isDirectory)
        let packageDirectory = bundleIdentifier == nil
            ? namespacedDirectory
            : namespacedDirectory.appending(path: "TextForSpeech", directoryHint: .isDirectory)

        return packageDirectory.appending(path: "profiles.json", directoryHint: .notDirectory)
    }

    func loadPersistedStateIfPresent() throws {
        try persistence.load()
    }

    func persistCurrentState() throws {
        try persistence.save()
    }

    func repairProfileState(persistIfChanged: Bool) throws {
        var didChangeState = false

        if storedCustomProfilesByID[TextForSpeech.Profile.default.id] == nil {
            storedCustomProfilesByID[TextForSpeech.Profile.default.id] = .default
            didChangeState = true
        }

        if storedCustomProfilesByID[activeCustomProfileID] == nil {
            activeCustomProfileID = TextForSpeech.Profile.default.id
            didChangeState = true
        }

        if persistIfChanged && didChangeState {
            try persistCurrentState()
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
