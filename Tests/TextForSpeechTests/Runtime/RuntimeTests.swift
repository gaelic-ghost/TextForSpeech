import Foundation
import Testing
@testable import TextForSpeech

// MARK: - Runtime

@Test func `runtime bootstraps stored default profile on first launch`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))

    #expect(runtime.style.getActive() == .balanced)
    #expect(runtime.profiles.getActive().profileID == "default")
    #expect(runtime.profiles.getActive().summary.id == "default")
    #expect(runtime.profiles.getActive().summary.replacementCount == 0)
    #expect(try runtime.profiles.get(id: "default").summary.id == "default")
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
}

@Test func `runtime style lists available built in styles`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let options = runtime.style.list()

    #expect(options.map(\.style) == [.balanced, .compact, .explicit])
    #expect(options.allSatisfy { !$0.summary.isEmpty })
}

@Test func `runtime summary provider lists available providers`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let options = runtime.summaryProvider.list()

    #expect(options.map(\.provider) == [.codexExec, .openAIResponses, .foundationModels])
    #expect(options.allSatisfy { !$0.summary.isEmpty })
}

@Test func `runtime normalize uses built in base and active custom profile`() async throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let custom = try runtime.profiles.create(name: "Custom")
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("bar", with: "baz", id: "custom-rule"),
        toProfile: custom.id,
    )
    try runtime.profiles.setActive(id: custom.id)

    let normalized = try await runtime.normalize.text("https://example.com and bar")

    #expect(runtime.baseProfile == .base)
    #expect(normalized.contains("example dot com"))
    #expect(normalized.contains("baz"))
}

@Test func `runtime async normalize skips external summarizer when summarize is false`() async throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    try runtime.summaryProvider.set(.openAIResponses)
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule"),
    )

    let normalized = try await runtime.normalize.text(
        "https://example.com and stderr",
        summarize: false,
    )

    #expect(normalized.contains("example dot com"))
    #expect(normalized.contains("standard error"))
}

@Test func `runtime getEffective merges active style with active custom profile`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let logs = try runtime.profiles.create(name: "Logs")
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule"),
        toProfile: logs.id,
    )
    try runtime.profiles.setActive(id: logs.id)

    let effective = runtime.profiles.getEffective()

    #expect(effective.profileID == logs.id)
    #expect(effective.summary.id == logs.id)
    #expect(effective.replacements.contains(where: { $0.id == "logs-rule" }))
    #expect(effective.replacements.contains(where: { $0.id == "base-url" }))
}

@Test func `runtime normalize can preview stored named profiles without activating them`() async throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let logs = try runtime.profiles.create(name: "Logs")
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule"),
        toProfile: logs.id,
    )

    let normalized = try await runtime.normalize.text("stderr", usingProfileID: logs.id)

    #expect(normalized == "standard error")
    #expect(runtime.profiles.getActive().profileID == "default")
}

@Test func `runtime normalize tracks later profile changes`() async throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    try runtime.renameActiveProfile(to: "Default")
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("foo", with: "bar", id: "foo-rule"),
    )

    let firstNormalized = try await runtime.normalize.text("foo")

    try runtime.renameActiveProfile(to: "Updated")
    _ = try runtime.profiles.patchReplacement(
        TextForSpeech.Replacement("foo", with: "baz", id: "foo-rule"),
    )

    let secondNormalized = try await runtime.normalize.text("foo")

    #expect(firstNormalized == "bar")
    #expect(secondNormalized == "baz")
    #expect(runtime.profiles.getActive().summary.name == "Updated")
}

@Test func `runtime can switch built in style and persist it`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let writer = try TextForSpeech.Runtime(persistence: .file(fileURL))
    try writer.style.setActive(to: .compact)

    #expect(writer.style.getActive() == .compact)
    #expect(writer.baseProfile == .builtInBase(style: .compact))

    let reader = try TextForSpeech.Runtime(persistence: .file(fileURL))

    #expect(reader.style.getActive() == .compact)
    #expect(reader.baseProfile == .builtInBase(style: .compact))
}

@Test func `runtime can switch summary provider and persist it`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let writer = try TextForSpeech.Runtime(persistence: .file(fileURL))
    try writer.summaryProvider.set(.openAIResponses)

    #expect(writer.summaryProvider.get() == .openAIResponses)

    let reader = try TextForSpeech.Runtime(persistence: .file(fileURL))

    #expect(reader.summaryProvider.get() == .openAIResponses)
}

@Test func `runtime creates profiles with generated ids and lists them in stable order`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))

    let zebra = try runtime.profiles.create(name: "Zebra")
    let alpha = try runtime.profiles.create(name: "Alpha")

    #expect(zebra.id == "zebra")
    #expect(alpha.summary.name == "Alpha")
    #expect(runtime.profiles.list().map(\.id) == ["alpha", "default", "zebra"])
}

@Test func `runtime create deduplicates generated ids from duplicate names`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))

    let first = try runtime.profiles.create(name: "Logs")
    let second = try runtime.profiles.create(name: "Logs")

    #expect(first.id == "logs")
    #expect(second.id == "logs-2")
}

@Test func `runtime get returns summary and replacements together`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let logs = try runtime.profiles.create(name: "Logs")
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule"),
        toProfile: logs.id,
    )

    let details = try runtime.profiles.get(id: logs.id)

    #expect(details.summary.id == logs.id)
    #expect(details.summary.replacementCount == 1)
    #expect(details.replacements.map(\.id) == ["stderr-rule"])
}

@Test func `runtime edits active and stored profile replacements`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    try runtime.renameActiveProfile(to: "Default")
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule"),
    )
    let logs = try runtime.profiles.create(name: "Logs")

    let activeProfile = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("stdout", with: "standard output", id: "stdout-rule"),
    )
    #expect(activeProfile.summary.replacementCount == 2)

    let storedProfile = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("panic", with: "runtime panic", id: "panic-rule"),
        toProfile: logs.id,
    )
    #expect(storedProfile.summary.replacementCount == 1)

    let replacedProfile = try runtime.profiles.patchReplacement(
        TextForSpeech.Replacement("panic", with: "fatal runtime panic", id: "panic-rule"),
        inProfile: logs.id,
    )
    #expect(replacedProfile.summary.replacementCount == 1)
    #expect(try runtime.profiles.get(id: logs.id).replacements.first?.replacement == "fatal runtime panic")

    let trimmedProfile = try runtime.profiles.removeReplacement(
        id: "panic-rule",
        fromProfile: logs.id,
    )
    #expect(trimmedProfile.summary.replacementCount == 0)
}

@Test func `runtime can rename and reset one stored profile`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let logs = try runtime.profiles.create(name: "Logs")
    let renamed = try runtime.profiles.rename(profile: logs.id, to: "Operations")
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("stdout", with: "standard output", id: "stdout-rule"),
        toProfile: logs.id,
    )

    try runtime.profiles.reset(id: logs.id)

    #expect(renamed.summary.name == "Operations")
    #expect(try runtime.profiles.get(id: logs.id).summary.name == "Operations")
    #expect(try runtime.profiles.get(id: logs.id).replacements.isEmpty)
}

@Test func `runtime persists active profile ID and stored profiles`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let writer = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let logs = try writer.profiles.create(name: "Logs")
    _ = try writer.profiles.addReplacement(
        TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule"),
        toProfile: logs.id,
    )
    let ops = try writer.profiles.create(name: "Ops")
    _ = try writer.profiles.addReplacement(
        TextForSpeech.Replacement("stdout", with: "standard output", id: "ops-rule"),
        toProfile: ops.id,
    )
    try writer.profiles.setActive(id: ops.id)

    let reader = try TextForSpeech.Runtime(persistence: .file(fileURL))

    #expect(reader.profiles.getActive().profileID == ops.id)
    #expect(reader.profiles.getActive().summary.id == ops.id)
    #expect(reader.profiles.getActive().replacements.first?.replacement == "standard output")
    #expect(try reader.profiles.get(id: logs.id).replacements.first?.replacement == "standard error")
}

@Test func `runtime falls back to default when persisted active profile is missing`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let state = TextForSpeech.PersistedState(
        version: 1,
        builtInStyle: .balanced,
        activeCustomProfileID: "missing",
        profiles: [
            "default": .default,
            "logs": TextForSpeech.Profile(id: "logs", name: "Logs"),
        ],
    )
    try write(state: state, to: fileURL)

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))

    #expect(runtime.profiles.getActive().profileID == "default")
    #expect(runtime.profiles.getActive().summary.id == "default")
}

@Test func `runtime defaults summary provider when persisted state predates provider setting`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let json = """
    {
      "activeCustomProfileID" : "default",
      "builtInStyle" : "balanced",
      "profiles" : {
        "default" : {
          "id" : "default",
          "name" : "Default",
          "replacements" : []
        }
      },
      "version" : 1
    }
    """
    try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
    )
    try Data(json.utf8).write(to: fileURL, options: .atomic)

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))

    #expect(runtime.summaryProvider.get() == .foundationModels)
}

@Test func `deleting active named profile reactivates default`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let logs = try runtime.profiles.create(name: "Logs")
    try runtime.profiles.setActive(id: logs.id)

    try runtime.profiles.delete(id: logs.id)

    #expect(runtime.profiles.getActive().profileID == "default")
    #expect(try runtime.profiles.get(id: "default").summary.id == "default")
}

@Test func `factoryReset clears stored custom profiles back to default only`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))
    let logs = try runtime.profiles.create(name: "Logs")
    _ = try runtime.profiles.addReplacement(
        TextForSpeech.Replacement("stdout", with: "standard output", id: "stdout-rule"),
        toProfile: logs.id,
    )

    try runtime.profiles.factoryReset()

    #expect(runtime.profiles.list().map(\.id) == ["default"])
    #expect(runtime.profiles.getActive().profileID == "default")
}

@Test func `runtime restore rejects unsupported persisted state version`() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let runtime = try TextForSpeech.Runtime(persistence: .file(fileURL))

    #expect(throws: TextForSpeech.PersistenceError.self) {
        try runtime.persistence.restore(
            TextForSpeech.PersistedState(
                version: 99,
                builtInStyle: .balanced,
                activeCustomProfileID: "default",
                profiles: [:],
            ),
        )
    }
}

@Test func `default persistence URL uses text for speech fallback when bundle identifier is missing`() {
    let url = TextForSpeech.Runtime.defaultPersistenceURL(bundle: .init())

    #expect(url.path.removingPercentEncoding?.contains("Application Support/TextForSpeech/profiles.json") == true)
}

@Test func `default persistence URL uses debug directory name for bundled targets in debug builds`() {
    let url = TextForSpeech.Runtime.defaultPersistenceURL(bundleIdentifier: "com.example.HostApp")

#if DEBUG
    #expect(url.path.removingPercentEncoding?.contains("Application Support/com.example.HostApp/TextForSpeech-Debug/profiles.json") == true)
#else
    #expect(url.path.removingPercentEncoding?.contains("Application Support/com.example.HostApp/TextForSpeech/profiles.json") == true)
#endif
}

private func write(state: TextForSpeech.PersistedState, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true,
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    try data.write(to: url, options: .atomic)
}

private extension TextForSpeech.Runtime {
    func renameActiveProfile(to name: String) throws {
        _ = try profiles.rename(profile: profiles.getActive().profileID, to: name)
    }
}
