import Testing
@testable import TextForSpeech

// MARK: - File Paths and Names

@Test func filePathsBecomeSpokenPaths() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
}

@Test func filePathsUseConfiguredGaleAliases() {
    let text = "Path: /Users/galem/Workspace/SpeakSwiftly."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("gale mini slash Workspace slash Speak Swiftly"))
}

@Test func dashedFilePathsBecomeSpeechSafeSpacing() {
    let text = "Path: /tmp/speak-to-user/path-now."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("tmp slash speak to user slash path now"))
    #expect(!normalized.contains("dash"))
}

@Test func filePathsInsideCurrentDirectoryOmitTheAbsolutePrefix() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextNormalizer.normalizeFilePaths(
        text,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
        )
    )

    #expect(normalized.contains("current directory slash Sources slash Speak Swiftly"))
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func filePathsInsideRepoRootButOutsideCurrentDirectoryKeepRepoRootContext() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/README.md."

    let normalized = TextNormalizer.normalizeFilePaths(
        text,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
        )
    )

    #expect(normalized.contains("repo root slash README dot md"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func standaloneGaleAliasesBecomeSpokenNames() {
    let text = "Please ask galew, galem, and Galew again."

    let normalized = TextNormalizer.normalizeStandaloneGaleAliases(text)

    #expect(normalized.contains("gale wumbo"))
    #expect(normalized.contains("gale mini"))
    #expect(normalized.contains("gale wumbo"))
}

// MARK: - Identifier and Code Speech

@Test func dottedIdentifiersBecomeSpokenIdentifiers() {
    let text = "Read NSApplication.didFinishLaunchingNotification once."

    let normalized = TextNormalizer.normalizeDottedIdentifiers(text)

    #expect(normalized.contains("NSApplication dot did Finish Launching Notification"))
}

@Test func snakeCaseIdentifiersBecomeSpokenIdentifiers() {
    let text = "Read snake_case_stuff once."

    let normalized = TextNormalizer.normalizeSnakeCaseIdentifiers(text)

    #expect(normalized.contains("snake case stuff"))
    #expect(!normalized.contains("underscore"))
}

@Test func dashedIdentifiersBecomeSpeechSafeSpacing() {
    let normalized = TextNormalizer.spokenIdentifier("kebab-case-stuff")

    #expect(normalized.contains("kebab case stuff"))
    #expect(!normalized.contains("dash"))
}

@Test func camelCaseIdentifiersBecomeSpokenIdentifiers() {
    let text = "Read camelCaseStuff once."

    let normalized = TextNormalizer.normalizeCamelCaseIdentifiers(text)

    #expect(normalized.contains("camel Case Stuff"))
}

@Test func codeHeavyLinesBecomeSpokenCode() {
    let text = #"let fallback = weirdWords.first(where: { $0.hasPrefix("q") }) ?? "nothing""#

    let normalized = TextNormalizer.normalizeCodeHeavyLines(text)

    #expect(normalized.contains("open brace"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func spiralProneWordsAreSpelledOut() {
    let text = "Also say chrommmaticallly and qqqwweerrtyy once."

    let normalized = TextNormalizer.normalizeSpiralProneWords(text)

    #expect(normalized.contains("c h r o m m m a t i c a l l l y"))
    #expect(normalized.contains("q q q w w e e r r t y y"))
}
