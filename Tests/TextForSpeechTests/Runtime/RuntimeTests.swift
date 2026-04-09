import Foundation
import Testing
@testable import TextForSpeech

// MARK: - Runtime

@Test func runtimeBootstrapsStoredDefaultProfileOnFirstLaunch() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)

    #expect(runtime.profiles.activeID == "default")
    #expect(runtime.profiles.active().id == "default")
    #expect(runtime.profiles.stored(id: "default") == .default)
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
}

@Test func runtimeMergesBaseAndActiveCustomProfilesForEffectiveSnapshots() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)
    try runtime.profiles.store(
        TextForSpeech.Profile(
            id: "custom",
            name: "Custom",
            replacements: [
                TextForSpeech.Replacement("bar", with: "baz", id: "custom-rule")
            ]
        )
    )
    try runtime.profiles.activate(id: "custom")

    let snapshot = runtime.profiles.effective()

    #expect(snapshot.id == "custom")
    #expect(snapshot.name == "Custom")
    #expect(snapshot.replacements.contains(where: { $0.id == "custom-rule" }))
    #expect(snapshot.replacements.contains(where: { $0.id == "base-url" }))
}

@Test func runtimeReturnsStableSnapshotsForLaterJobs() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)
    try runtime.storeActiveProfile(
        TextForSpeech.Profile(
            id: "default",
            name: "Default",
            replacements: [
                TextForSpeech.Replacement("foo", with: "bar", id: "foo-rule")
            ]
        )
    )

    let firstSnapshot = runtime.profiles.effective()

    try runtime.storeActiveProfile(
        TextForSpeech.Profile(
            id: "default",
            name: "Updated",
            replacements: [
                TextForSpeech.Replacement("foo", with: "baz", id: "foo-rule")
            ]
        )
    )

    let secondSnapshot = runtime.profiles.effective()

    #expect(firstSnapshot.name == "Default")
    #expect(firstSnapshot.replacement(id: "foo-rule")?.replacement == "bar")
    #expect(secondSnapshot.name == "Updated")
    #expect(secondSnapshot.replacement(id: "foo-rule")?.replacement == "baz")
}

@Test func runtimeCanPreviewStoredNamedProfilesWithoutActivatingThem() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)
    try runtime.profiles.store(
        TextForSpeech.Profile(
            id: "logs",
            name: "Logs",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule")
            ]
        )
    )

    let snapshot = runtime.profiles.effective(id: "logs")

    #expect(snapshot?.id == "logs")
    #expect(snapshot?.replacements.contains(where: { $0.id == "logs-rule" }) == true)
    #expect(runtime.profiles.activeID == "default")
}

@Test func runtimeCreatesProfilesAndListsThemInStableOrder() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)

    let zebra = try runtime.profiles.create(id: "zebra", name: "Zebra")
    let alpha = try runtime.profiles.create(id: "alpha", name: "Alpha")

    #expect(zebra.id == "zebra")
    #expect(alpha.name == "Alpha")
    #expect(runtime.profiles.list().map(\.id) == ["alpha", "default", "zebra"])
}

@Test func runtimeEditsActiveAndStoredProfileReplacements() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)
    try runtime.storeActiveProfile(
        TextForSpeech.Profile(
            id: "default",
            name: "Default",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule")
            ]
        )
    )
    _ = try runtime.profiles.create(id: "logs", name: "Logs")

    let activeProfile = try runtime.profiles.add(
        TextForSpeech.Replacement("stdout", with: "standard output", id: "stdout-rule")
    )
    #expect(activeProfile.replacements.map(\.id).contains("stdout-rule"))

    let storedProfile = try runtime.profiles.add(
        TextForSpeech.Replacement("panic", with: "runtime panic", id: "panic-rule"),
        toProfileID: "logs"
    )
    #expect(storedProfile.replacements.map(\.id) == ["panic-rule"])

    let replacedProfile = try runtime.profiles.replace(
        TextForSpeech.Replacement("panic", with: "fatal runtime panic", id: "panic-rule"),
        inProfileID: "logs"
    )
    #expect(replacedProfile.replacement(id: "panic-rule")?.replacement == "fatal runtime panic")

    let trimmedProfile = try runtime.profiles.removeReplacement(
        id: "panic-rule",
        fromProfileID: "logs"
    )
    #expect(trimmedProfile.replacements.isEmpty)
}

@Test func runtimePersistsActiveProfileIDAndStoredProfiles() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let writer = try TextForSpeech.Runtime(persistenceURL: fileURL)
    try writer.profiles.store(
        TextForSpeech.Profile(
            id: "logs",
            name: "Logs",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule")
            ]
        )
    )
    try writer.profiles.store(
        TextForSpeech.Profile(
            id: "ops",
            name: "Ops",
            replacements: [
                TextForSpeech.Replacement("stdout", with: "standard output", id: "ops-rule")
            ]
        )
    )
    try writer.profiles.activate(id: "ops")

    let reader = try TextForSpeech.Runtime(persistenceURL: fileURL)

    #expect(reader.profiles.activeID == "ops")
    #expect(reader.profiles.active().replacement(id: "ops-rule")?.replacement == "standard output")
    #expect(reader.profiles.stored(id: "logs")?.replacement(id: "logs-rule")?.replacement == "standard error")
}

@Test func runtimeFallsBackToDefaultWhenPersistedActiveProfileIsMissing() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let state = TextForSpeech.PersistedState(
        version: 1,
        activeCustomProfileID: "missing",
        profiles: [
            "default": .default,
            "logs": TextForSpeech.Profile(id: "logs", name: "Logs"),
        ]
    )
    try write(state: state, to: fileURL)

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)

    #expect(runtime.profiles.activeID == "default")
    #expect(runtime.profiles.active() == .default)
}

@Test func deletingActiveNamedProfileReactivatesDefault() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)
    try runtime.profiles.store(TextForSpeech.Profile(id: "logs", name: "Logs"))
    try runtime.profiles.activate(id: "logs")

    try runtime.profiles.delete(id: "logs")

    #expect(runtime.profiles.activeID == "default")
    #expect(runtime.profiles.stored(id: "default") == .default)
}

@Test func deletingDefaultProfileRecreatesEmptyDefault() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)

    try runtime.profiles.delete(id: "default")

    #expect(runtime.profiles.activeID == "default")
    #expect(runtime.profiles.stored(id: "default") == .default)
}

@Test func runtimeRestoreRejectsUnsupportedPersistedStateVersion() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistenceURL: fileURL)

    #expect(throws: TextForSpeech.PersistenceError.self) {
        try runtime.persistence.restore(
            TextForSpeech.PersistedState(
                version: 99,
                activeCustomProfileID: "default",
                profiles: [:]
            )
        )
    }
}

@Test func defaultPersistenceURLUsesTextForSpeechFallbackWhenBundleIdentifierIsMissing() {
    let url = TextForSpeech.Runtime.defaultPersistenceURL(bundle: .init())

    #expect(url.path.removingPercentEncoding?.contains("Application Support/TextForSpeech/profiles.json") == true)
}

private func write(state: TextForSpeech.PersistedState, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    try data.write(to: url, options: .atomic)
}

private extension TextForSpeech.Runtime {
    func storeActiveProfile(_ profile: TextForSpeech.Profile) throws {
        try profiles.store(profile)
        try profiles.activate(id: profile.id)
    }
}
