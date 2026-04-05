import Foundation
import Testing
@testable import TextForSpeech

// MARK: - Runtime

@Test func runtimeMergesBaseAndCustomProfilesForSnapshots() {
    let runtime = TextForSpeechRuntime(
        baseProfile: TextForSpeech.Profile(
            id: "base",
            name: "Base",
            replacements: [
                TextForSpeech.Replacement("foo", with: "bar", id: "base-rule")
            ]
        ),
        customProfile: TextForSpeech.Profile(
            id: "custom",
            name: "Custom",
            replacements: [
                TextForSpeech.Replacement("bar", with: "baz", id: "custom-rule")
            ]
        )
    )

    let snapshot = runtime.snapshot()

    #expect(snapshot.id == "custom")
    #expect(snapshot.name == "Custom")
    #expect(snapshot.replacements.map(\.id) == ["base-rule", "custom-rule"])
}

@Test func runtimeReturnsStableSnapshotsForLaterJobs() {
    let runtime = TextForSpeechRuntime(
        customProfile: TextForSpeech.Profile(
            id: "default",
            name: "Default",
            replacements: [
                TextForSpeech.Replacement("foo", with: "bar")
            ]
        )
    )

    let firstSnapshot = runtime.snapshot()
    runtime.use(
        TextForSpeech.Profile(
            id: "default",
            name: "Updated",
            replacements: [
                TextForSpeech.Replacement("foo", with: "baz")
            ]
        )
    )
    let secondSnapshot = runtime.snapshot()

    #expect(firstSnapshot.name == "Default")
    #expect(firstSnapshot.replacements.last?.replacement == "bar")
    #expect(secondSnapshot.name == "Updated")
    #expect(secondSnapshot.replacements.last?.replacement == "baz")
}

@Test func runtimeCanSnapshotStoredNamedProfiles() {
    let runtime = TextForSpeechRuntime()
    let logsProfile = TextForSpeech.Profile(
        id: "logs",
        name: "Logs",
        replacements: [
            TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule")
        ]
    )

    runtime.store(logsProfile)
    let snapshot = runtime.snapshot(named: "logs")

    #expect(snapshot.id == "logs")
    #expect(snapshot.replacements.map(\.id) == ["logs-rule"])
}

@Test func runtimeCreatesProfilesAndListsThemInStableOrder() throws {
    let runtime = TextForSpeechRuntime()

    let zebra = try runtime.createProfile(id: "zebra", named: "Zebra")
    let alpha = try runtime.createProfile(id: "alpha", named: "Alpha")

    #expect(zebra.id == "zebra")
    #expect(alpha.name == "Alpha")
    #expect(runtime.storedProfiles().map(\.id) == ["alpha", "zebra"])
}

@Test func runtimeEditsCustomAndStoredProfileReplacements() throws {
    let runtime = TextForSpeechRuntime(
        customProfile: TextForSpeech.Profile(
            id: "default",
            name: "Default",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule")
            ]
        )
    )
    _ = try runtime.createProfile(id: "logs", named: "Logs")

    let customProfile = runtime.addReplacement(
        TextForSpeech.Replacement("stdout", with: "standard output", id: "stdout-rule")
    )
    #expect(customProfile.replacements.map(\.id) == ["stderr-rule", "stdout-rule"])

    let storedProfile = try runtime.addReplacement(
        TextForSpeech.Replacement("panic", with: "runtime panic", id: "panic-rule"),
        toStoredProfileNamed: "logs"
    )
    #expect(storedProfile.replacements.map(\.id) == ["panic-rule"])

    let replacedProfile = try runtime.replaceReplacement(
        TextForSpeech.Replacement("panic", with: "fatal runtime panic", id: "panic-rule"),
        inStoredProfileNamed: "logs"
    )
    #expect(replacedProfile.replacements.first?.replacement == "fatal runtime panic")

    let trimmedProfile = try runtime.removeReplacement(
        id: "panic-rule",
        fromStoredProfileNamed: "logs"
    )
    #expect(trimmedProfile.replacements.isEmpty)
}

@Test func runtimeSavesAndLoadsPersistedProfiles() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "text-profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let writer = TextForSpeechRuntime(persistenceURL: fileURL)
    writer.store(
        TextForSpeech.Profile(
            id: "logs",
            name: "Logs",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule")
            ]
        )
    )
    writer.use(
        TextForSpeech.Profile(
            id: "ops",
            name: "Ops",
            replacements: [
                TextForSpeech.Replacement("stdout", with: "standard output", id: "ops-rule")
            ]
        )
    )

    try writer.save()

    let reader = TextForSpeechRuntime(persistenceURL: fileURL)
    try reader.load()

    #expect(reader.customProfile.id == "ops")
    #expect(reader.customProfile.replacements.map(\.id) == ["ops-rule"])
    #expect(reader.profile(named: "logs")?.replacements.map(\.id) == ["logs-rule"])
}

@Test func runtimeRestoreRejectsUnsupportedPersistedStateVersion() {
    let runtime = TextForSpeechRuntime()

    #expect(throws: TextForSpeech.PersistenceError.self) {
        try runtime.restore(
            TextForSpeech.PersistedState(
                version: 99,
                customProfile: .default,
                profiles: [:]
            )
        )
    }
}
