import Foundation
import Observation

// MARK: - Runtime

@Observable
public final class TextForSpeechRuntime {
    private enum Persistence {
        static let currentVersion = 1
    }

    // MARK: Public State

    public let baseProfile: TextForSpeech.Profile
    public var customProfile: TextForSpeech.Profile
    public private(set) var profiles: [String: TextForSpeech.Profile]
    public let persistenceURL: URL?
    private let fileManager: FileManager

    public init(
        baseProfile: TextForSpeech.Profile = .base,
        customProfile: TextForSpeech.Profile = .default,
        profiles: [String: TextForSpeech.Profile] = [:],
        persistenceURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.baseProfile = baseProfile
        self.customProfile = customProfile
        self.profiles = profiles
        self.persistenceURL = persistenceURL?.standardizedFileURL
        self.fileManager = fileManager
    }

    // MARK: Profiles

    public var persistedState: TextForSpeech.PersistedState {
        TextForSpeech.PersistedState(
            version: Persistence.currentVersion,
            customProfile: customProfile,
            profiles: profiles
        )
    }

    public func profile(named id: String) -> TextForSpeech.Profile? {
        profiles[id]
    }

    public func storedProfiles() -> [TextForSpeech.Profile] {
        profiles.values.sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.id < rhs.id
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func effectiveProfile(named id: String? = nil) -> TextForSpeech.Profile {
        let selectedProfile = id.flatMap { profiles[$0] } ?? customProfile
        return baseProfile.merged(with: selectedProfile)
    }

    public func snapshot(named id: String? = nil) -> TextForSpeech.Profile {
        effectiveProfile(named: id)
    }

    public func use(_ profile: TextForSpeech.Profile) {
        customProfile = profile
    }

    public func store(_ profile: TextForSpeech.Profile) {
        profiles[profile.id] = profile
    }

    public func createProfile(
        id: String,
        named name: String,
        replacements: [TextForSpeech.Replacement] = []
    ) throws -> TextForSpeech.Profile {
        guard profiles[id] == nil else {
            throw TextForSpeech.RuntimeError.profileAlreadyExists(id)
        }

        let profile = TextForSpeech.Profile(
            id: id,
            name: name,
            replacements: replacements
        )
        profiles[id] = profile
        return profile
    }

    public func removeProfile(named id: String) {
        profiles.removeValue(forKey: id)
        if customProfile.id == id {
            customProfile = .default
        }
    }

    // MARK: Replacements

    public func addReplacement(
        _ replacement: TextForSpeech.Replacement
    ) -> TextForSpeech.Profile {
        let updatedProfile = customProfile.adding(replacement)
        customProfile = updatedProfile
        return updatedProfile
    }

    public func addReplacement(
        _ replacement: TextForSpeech.Replacement,
        toStoredProfileNamed id: String
    ) throws -> TextForSpeech.Profile {
        let updatedProfile = try storedProfile(named: id).adding(replacement)
        profiles[id] = updatedProfile
        return updatedProfile
    }

    public func replaceReplacement(
        _ replacement: TextForSpeech.Replacement
    ) throws -> TextForSpeech.Profile {
        let updatedProfile = try customProfile.replacing(replacement)
        customProfile = updatedProfile
        return updatedProfile
    }

    public func replaceReplacement(
        _ replacement: TextForSpeech.Replacement,
        inStoredProfileNamed id: String
    ) throws -> TextForSpeech.Profile {
        let updatedProfile = try storedProfile(named: id).replacing(replacement)
        profiles[id] = updatedProfile
        return updatedProfile
    }

    public func removeReplacement(
        id replacementID: String
    ) throws -> TextForSpeech.Profile {
        let updatedProfile = try customProfile.removingReplacement(id: replacementID)
        customProfile = updatedProfile
        return updatedProfile
    }

    public func removeReplacement(
        id replacementID: String,
        fromStoredProfileNamed profileID: String
    ) throws -> TextForSpeech.Profile {
        let updatedProfile = try storedProfile(named: profileID).removingReplacement(id: replacementID)
        profiles[profileID] = updatedProfile
        return updatedProfile
    }

    public func reset() {
        customProfile = .default
    }

    // MARK: Persistence

    public func restore(_ state: TextForSpeech.PersistedState) throws {
        guard state.version == Persistence.currentVersion else {
            throw TextForSpeech.PersistenceError.unsupportedPersistedStateVersion(state.version)
        }

        customProfile = state.customProfile
        profiles = state.profiles
    }

    public func load() throws {
        guard let persistenceURL else {
            throw TextForSpeech.PersistenceError.missingPersistenceURL
        }

        try load(from: persistenceURL)
    }

    public func load(from url: URL) throws {
        let fileURL = url.standardizedFileURL
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

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
        guard let persistenceURL else {
            throw TextForSpeech.PersistenceError.missingPersistenceURL
        }

        try save(to: persistenceURL)
    }

    public func save(to url: URL) throws {
        let fileURL = url.standardizedFileURL
        let directoryURL = fileURL.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(
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
            data = try encoder.encode(persistedState)
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

    // MARK: Helpers

    private func storedProfile(named id: String) throws -> TextForSpeech.Profile {
        guard let profile = profiles[id] else {
            throw TextForSpeech.RuntimeError.profileNotFound(id)
        }
        return profile
    }
}
