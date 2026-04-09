import Foundation
import Observation

// MARK: - Runtime

public extension TextForSpeech {
    @Observable
    final class Runtime {
        private enum Versioning {
            static let currentPersistedStateVersion = 1
        }

        private var customProfile: TextForSpeech.Profile
        private var storedProfilesByID: [String: TextForSpeech.Profile]
        public let persistenceURL: URL?
        private let fileManager: FileManager

        public init(
            customProfile: TextForSpeech.Profile = .default,
            profiles: [String: TextForSpeech.Profile] = [:],
            persistenceURL: URL? = nil,
            fileManager: FileManager = .default
        ) {
            self.customProfile = customProfile
            storedProfilesByID = profiles
            self.persistenceURL = persistenceURL?.standardizedFileURL
            self.fileManager = fileManager
        }
    }
}

public extension TextForSpeech.Runtime {
    struct Profiles {
        fileprivate let runtime: TextForSpeech.Runtime

        public func active(id: String? = nil) -> TextForSpeech.Profile? {
            id.flatMap { runtime.storedProfilesByID[$0] } ?? runtime.customProfile
        }

        public func stored(id: String) -> TextForSpeech.Profile? {
            runtime.storedProfilesByID[id]
        }

        public func list() -> [TextForSpeech.Profile] {
            runtime.storedProfilesByID.values.sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }

        public func effective(id: String? = nil) -> TextForSpeech.Profile? {
            guard let activeProfile = active(id: id) else { return nil }
            return TextForSpeech.Profile.base.merged(with: activeProfile)
        }

        public func use(_ profile: TextForSpeech.Profile) {
            runtime.customProfile = profile
        }

        public func store(_ profile: TextForSpeech.Profile) {
            runtime.storedProfilesByID[profile.id] = profile
        }

        @discardableResult
        public func create(
            id: String,
            name: String,
            replacements: [TextForSpeech.Replacement] = []
        ) throws -> TextForSpeech.Profile {
            guard runtime.storedProfilesByID[id] == nil else {
                throw TextForSpeech.RuntimeError.profileAlreadyExists(id)
            }

            let profile = TextForSpeech.Profile(
                id: id,
                name: name,
                replacements: replacements
            )
            runtime.storedProfilesByID[id] = profile
            return profile
        }

        public func delete(id: String) {
            runtime.storedProfilesByID.removeValue(forKey: id)
            if runtime.customProfile.id == id {
                runtime.customProfile = .default
            }
        }

        @discardableResult
        public func add(
            _ replacement: TextForSpeech.Replacement
        ) -> TextForSpeech.Profile {
            let updatedProfile = runtime.customProfile.adding(replacement)
            runtime.customProfile = updatedProfile
            return updatedProfile
        }

        @discardableResult
        public func add(
            _ replacement: TextForSpeech.Replacement,
            toStoredProfileID id: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: id).adding(replacement)
            runtime.storedProfilesByID[id] = updatedProfile
            return updatedProfile
        }

        @discardableResult
        public func replace(
            _ replacement: TextForSpeech.Replacement
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try runtime.customProfile.replacing(replacement)
            runtime.customProfile = updatedProfile
            return updatedProfile
        }

        @discardableResult
        public func replace(
            _ replacement: TextForSpeech.Replacement,
            inStoredProfileID id: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: id).replacing(replacement)
            runtime.storedProfilesByID[id] = updatedProfile
            return updatedProfile
        }

        @discardableResult
        public func removeReplacement(
            id replacementID: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try runtime.customProfile.removingReplacement(id: replacementID)
            runtime.customProfile = updatedProfile
            return updatedProfile
        }

        @discardableResult
        public func removeReplacement(
            id replacementID: String,
            fromStoredProfileID profileID: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: profileID).removingReplacement(id: replacementID)
            runtime.storedProfilesByID[profileID] = updatedProfile
            return updatedProfile
        }

        public func reset() {
            runtime.customProfile = .default
        }

        private func storedProfile(id: String) throws -> TextForSpeech.Profile {
            guard let profile = runtime.storedProfilesByID[id] else {
                throw TextForSpeech.RuntimeError.profileNotFound(id)
            }
            return profile
        }
    }

    struct Persistence {
        fileprivate let runtime: TextForSpeech.Runtime

        public var state: TextForSpeech.PersistedState {
            TextForSpeech.PersistedState(
                version: Versioning.currentPersistedStateVersion,
                customProfile: runtime.customProfile,
                profiles: runtime.storedProfilesByID
            )
        }

        public func restore(_ state: TextForSpeech.PersistedState) throws {
            guard state.version == Versioning.currentPersistedStateVersion else {
                throw TextForSpeech.PersistenceError.unsupportedPersistedStateVersion(state.version)
            }

            runtime.customProfile = state.customProfile
            runtime.storedProfilesByID = state.profiles
        }

        public func load() throws {
            guard let persistenceURL = runtime.persistenceURL else {
                throw TextForSpeech.PersistenceError.missingPersistenceURL
            }

            try load(from: persistenceURL)
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
            guard let persistenceURL = runtime.persistenceURL else {
                throw TextForSpeech.PersistenceError.missingPersistenceURL
            }

            try save(to: persistenceURL)
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
}
