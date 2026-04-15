import Foundation

// MARK: - Runtime Storage

extension TextForSpeech.Runtime {
    static func defaultPersistenceURL(bundleIdentifier: String?) -> URL {
        let packageDirectoryName = defaultPersistenceDirectoryName
        let namespace = bundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? "TextForSpeech"
        let namespacedDirectory = URL.applicationSupportDirectory
            .appending(path: namespace, directoryHint: .isDirectory)
        let packageDirectory = bundleIdentifier == nil
            ? namespacedDirectory
            : namespacedDirectory.appending(path: packageDirectoryName, directoryHint: .isDirectory)

        return packageDirectory.appending(path: "profiles.json", directoryHint: .notDirectory)
    }

    static var defaultPersistenceDirectoryName: String {
#if DEBUG
        "TextForSpeech-Debug"
#else
        "TextForSpeech"
#endif
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

        if persistIfChanged, didChangeState {
            try persistCurrentState()
        }
    }
}

// MARK: - String Helpers

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
