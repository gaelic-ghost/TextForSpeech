import Foundation

public extension TextForSpeech.Runtime.Persistence {
    var state: TextForSpeech.PersistedState {
        TextForSpeech.PersistedState(
            version: TextForSpeech.Runtime.Versioning.currentPersistedStateVersion,
            builtInStyle: runtime.builtInStyle,
            activeCustomProfileID: runtime.activeCustomProfileID,
            profiles: runtime.storedCustomProfilesByID,
        )
    }

    func restore(_ state: TextForSpeech.PersistedState) throws {
        guard state.version == TextForSpeech.Runtime.Versioning.currentPersistedStateVersion else {
            throw TextForSpeech.PersistenceError.unsupportedPersistedStateVersion(state.version)
        }

        runtime.builtInStyle = state.builtInStyle
        runtime.activeCustomProfileID = state.activeCustomProfileID
        runtime.storedCustomProfilesByID = state.profiles
        try runtime.repairProfileState(persistIfChanged: false)
    }

    func load() throws {
        try load(from: runtime.persistenceURL)
    }

    func load(from url: URL) throws {
        let fileURL = url.standardizedFileURL
        guard runtime.fileManager.fileExists(atPath: fileURL.path) else { return }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw TextForSpeech.PersistenceError.couldNotRead(
                fileURL,
                error.localizedDescription,
            )
        }

        let state: TextForSpeech.PersistedState
        do {
            state = try JSONDecoder().decode(TextForSpeech.PersistedState.self, from: data)
        } catch {
            throw TextForSpeech.PersistenceError.couldNotDecode(
                fileURL,
                error.localizedDescription,
            )
        }

        try restore(state)
    }

    func save() throws {
        try save(to: runtime.persistenceURL)
    }

    func save(to url: URL) throws {
        let fileURL = url.standardizedFileURL
        let directoryURL = fileURL.deletingLastPathComponent()

        do {
            try runtime.fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
            )
        } catch {
            throw TextForSpeech.PersistenceError.couldNotCreateDirectory(
                directoryURL,
                error.localizedDescription,
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
                "TextForSpeech could not encode the current profile state before writing it. \(error.localizedDescription)",
            )
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw TextForSpeech.PersistenceError.couldNotWrite(
                fileURL,
                error.localizedDescription,
            )
        }
    }
}
