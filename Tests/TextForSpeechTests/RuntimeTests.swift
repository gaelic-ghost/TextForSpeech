import Foundation
import Testing
@testable import TextForSpeech

// MARK: - Runtime

@Test func runtimeMergesBaseAndCustomProfilesForSnapshots() {
    let runtime = TextForSpeech.Runtime(
        customProfile: TextForSpeech.Profile(
            id: "custom",
            name: "Custom",
            replacements: [
                TextForSpeech.Replacement("bar", with: "baz", id: "custom-rule")
            ]
        )
    )

    let snapshot = runtime.profiles.effective()

    #expect(snapshot?.id == "custom")
    #expect(snapshot?.name == "Custom")
    #expect(snapshot?.replacements.map(\.id) == ["custom-rule"])
}

@Test func runtimeReturnsStableSnapshotsForLaterJobs() {
    let runtime = TextForSpeech.Runtime(
        customProfile: TextForSpeech.Profile(
            id: "default",
            name: "Default",
            replacements: [
                TextForSpeech.Replacement("foo", with: "bar")
            ]
        )
    )

    let firstSnapshot = runtime.profiles.effective()
    runtime.profiles.use(
        TextForSpeech.Profile(
            id: "default",
            name: "Updated",
            replacements: [
                TextForSpeech.Replacement("foo", with: "baz")
            ]
        )
    )
    let secondSnapshot = runtime.profiles.effective()

    #expect(firstSnapshot?.name == "Default")
    #expect(firstSnapshot?.replacements.last?.replacement == "bar")
    #expect(secondSnapshot?.name == "Updated")
    #expect(secondSnapshot?.replacements.last?.replacement == "baz")
}

@Test func runtimeCanSnapshotStoredNamedProfiles() {
    let runtime = TextForSpeech.Runtime()
    let logsProfile = TextForSpeech.Profile(
        id: "logs",
        name: "Logs",
        replacements: [
            TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule")
        ]
    )

    runtime.profiles.store(logsProfile)
    let snapshot = runtime.profiles.effective(id: "logs")

    #expect(snapshot?.id == "logs")
    #expect(snapshot?.replacements.map(\.id) == ["logs-rule"])
}

@Test func runtimeCreatesProfilesAndListsThemInStableOrder() throws {
    let runtime = TextForSpeech.Runtime()

    let zebra = try runtime.profiles.create(id: "zebra", name: "Zebra")
    let alpha = try runtime.profiles.create(id: "alpha", name: "Alpha")

    #expect(zebra.id == "zebra")
    #expect(alpha.name == "Alpha")
    #expect(runtime.profiles.list().map(\.id) == ["alpha", "zebra"])
}

@Test func runtimeEditsCustomAndStoredProfileReplacements() throws {
    let runtime = TextForSpeech.Runtime(
        customProfile: TextForSpeech.Profile(
            id: "default",
            name: "Default",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule")
            ]
        )
    )
    _ = try runtime.profiles.create(id: "logs", name: "Logs")

    let customProfile = runtime.profiles.add(
        TextForSpeech.Replacement("stdout", with: "standard output", id: "stdout-rule")
    )
    #expect(customProfile.replacements.map(\.id) == ["stderr-rule", "stdout-rule"])

    let storedProfile = try runtime.profiles.add(
        TextForSpeech.Replacement("panic", with: "runtime panic", id: "panic-rule"),
        toStoredProfileID: "logs"
    )
    #expect(storedProfile.replacements.map(\.id) == ["panic-rule"])

    let replacedProfile = try runtime.profiles.replace(
        TextForSpeech.Replacement("panic", with: "fatal runtime panic", id: "panic-rule"),
        inStoredProfileID: "logs"
    )
    #expect(replacedProfile.replacements.first?.replacement == "fatal runtime panic")

    let trimmedProfile = try runtime.profiles.removeReplacement(
        id: "panic-rule",
        fromStoredProfileID: "logs"
    )
    #expect(trimmedProfile.replacements.isEmpty)
}

@Test func runtimeSavesAndLoadsPersistedProfiles() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "text-profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let writer = TextForSpeech.Runtime(persistenceURL: fileURL)
    writer.profiles.store(
        TextForSpeech.Profile(
            id: "logs",
            name: "Logs",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule")
            ]
        )
    )
    writer.profiles.use(
        TextForSpeech.Profile(
            id: "ops",
            name: "Ops",
            replacements: [
                TextForSpeech.Replacement("stdout", with: "standard output", id: "ops-rule")
            ]
        )
    )

    try writer.persistence.save()

    let reader = TextForSpeech.Runtime(persistenceURL: fileURL)
    try reader.persistence.load()

    #expect(reader.profiles.active()?.id == "ops")
    #expect(reader.profiles.active()?.replacements.map(\.id) == ["ops-rule"])
    #expect(reader.profiles.stored(id: "logs")?.replacements.map(\.id) == ["logs-rule"])
}

@Test func runtimeRestoreRejectsUnsupportedPersistedStateVersion() {
    let runtime = TextForSpeech.Runtime()

    #expect(throws: TextForSpeech.PersistenceError.self) {
        try runtime.persistence.restore(
            TextForSpeech.PersistedState(
                version: 99,
                customProfile: .default,
                profiles: [:]
            )
        )
    }
}
