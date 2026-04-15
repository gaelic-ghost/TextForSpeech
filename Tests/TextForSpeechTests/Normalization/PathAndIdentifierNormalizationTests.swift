import Testing
@testable import TextForSpeech

// MARK: - File Paths and Names

@Test func `file paths become spoken paths`() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
}

@Test func `file paths use configured gale aliases`() {
    let text = "Path: /Users/galem/Workspace/SpeakSwiftly."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("gale mini slash Workspace slash Speak Swiftly"))
}

@Test func `dashed file paths become speech safe spacing`() {
    let text = "Path: /tmp/speak-to-user/path-now."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("tmp slash speak to user slash path now"))
    #expect(!normalized.contains("dash"))
}

@Test func `file paths inside current directory omit the absolute prefix`() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextNormalizer.normalizeFilePaths(
        text,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
        ),
    )

    #expect(normalized.contains("current directory slash Sources slash Speak Swiftly"))
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func `file paths inside repo root but outside current directory keep repo root context`() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/README.md."

    let normalized = TextNormalizer.normalizeFilePaths(
        text,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
        ),
    )

    #expect(normalized.contains("repo root slash README dot md"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func `standalone gale aliases become spoken names`() {
    let text = "Please ask galew, galem, and Galew again."

    let normalized = TextNormalizer.normalizeStandaloneGaleAliases(text)

    #expect(normalized.contains("gale wumbo"))
    #expect(normalized.contains("gale mini"))
    #expect(normalized.contains("gale wumbo"))
}

@Test func `file paths speak known extension aliases naturally`() {
    let text = """
    Read /tmp/App.xcodeproj, project.pbxproj, Workspace.xcworkspace, Build.xcconfig, App.xcscheme, App.xctestplan, Run.xcresult, Assets.xcassets, Localizable.xcstrings, PrivacyInfo.xcprivacy, App.entitlements, App.dSYM, guide.mdx, page.tsx, widget.jsx, settings.jsonc, config.toml, workflow.yaml, workflow.yml, notebook.ipynb, module.wasm, cache.sqlite, and state.db.
    """

    let normalized = TextForSpeech.Normalize.text(text)

    #expect(normalized.contains("App dot xcode project"))
    #expect(normalized.contains("project dot xcode project file"))
    #expect(normalized.contains("Workspace dot xcode workspace"))
    #expect(normalized.contains("Build dot xcode config"))
    #expect(normalized.contains("App dot xcode scheme"))
    #expect(normalized.contains("App dot xcode test plan"))
    #expect(normalized.contains("Run dot xcode result bundle"))
    #expect(normalized.contains("Assets dot xcode asset catalog"))
    #expect(normalized.contains("Localizable dot xcode string catalog"))
    #expect(normalized.contains("Privacy Info dot privacy manifest"))
    #expect(normalized.contains("App dot entitlements"))
    #expect(normalized.contains("App dot debug symbols bundle"))
    #expect(normalized.contains("guide dot markdown jsx"))
    #expect(normalized.contains("page dot typescript jsx"))
    #expect(normalized.contains("widget dot javascript jsx"))
    #expect(normalized.contains("settings dot json with comments"))
    #expect(normalized.contains("config dot toml"))
    #expect(normalized.contains("workflow dot yaml"))
    #expect(normalized.contains("notebook dot jupyter notebook"))
    #expect(normalized.contains("module dot web assembly"))
    #expect(normalized.contains("cache dot sqlite database"))
    #expect(normalized.contains("state dot database"))
}

@Test func `file line references preserve line narration after extension aliases`() {
    let text = "Inspect project.pbxproj:42:7 and App.xcodeproj:18."

    let normalized = TextForSpeech.Normalize.text(text, format: .plain)

    #expect(normalized.contains("project dot xcode project file line 42 column 7"))
    #expect(normalized.contains("App dot xcode project at line 18"))
}

// MARK: - Identifier and Code Speech

@Test func `dotted identifiers become spoken identifiers`() {
    let text = "Read NSApplication.didFinishLaunchingNotification once."

    let normalized = TextNormalizer.normalizeDottedIdentifiers(text)

    #expect(normalized.contains("NSApplication dot did Finish Launching Notification"))
}

@Test func `dotted identifiers accept hyphenated alias segments`() {
    let normalized = TextNormalizer.normalizeDottedIdentifiers("guide.markdown-jsx")

    #expect(normalized.contains("guide dot markdown jsx"))
}

@Test func `snake case identifiers become spoken identifiers`() {
    let text = "Read snake_case_stuff once."

    let normalized = TextNormalizer.normalizeSnakeCaseIdentifiers(text)

    #expect(normalized.contains("snake case stuff"))
    #expect(!normalized.contains("underscore"))
}

@Test func `dashed identifiers become speech safe spacing`() {
    let normalized = TextNormalizer.spokenIdentifier("kebab-case-stuff")

    #expect(normalized.contains("kebab case stuff"))
    #expect(!normalized.contains("dash"))
}

@Test func `camel case identifiers become spoken identifiers`() {
    let text = "Read camelCaseStuff once."

    let normalized = TextNormalizer.normalizeCamelCaseIdentifiers(text)

    #expect(normalized.contains("camel Case Stuff"))
}

@Test func `math and typed identifiers become speech safe phrases`() {
    let text = "Read cosF32, sinF64, and tanU32 once."

    let normalized = TextForSpeech.Normalize.text(text, format: .plain)

    #expect(normalized.contains("cosine float thirty two"))
    #expect(normalized.contains("sine float sixty four"))
    #expect(normalized.contains("tangent unsigned integer thirty two"))
}

@Test func `standalone typed scalar tokens use base pronunciations`() {
    let text = "Use f32, i64, and usize once."

    let normalized = TextForSpeech.Normalize.text(text, format: .plain)

    #expect(normalized.contains("float thirty two"))
    #expect(normalized.contains("signed integer sixty four"))
    #expect(normalized.contains("unsigned integer size"))
}

@Test func `line only file references use at line narration`() {
    let text = "Read MarvisTTSModel.swift:208 once."

    let normalized = TextForSpeech.Normalize.text(text, format: .plain)

    #expect(normalized.contains("Marvis TTS Model dot swift at line 208"))
}

@Test func `code heavy lines become spoken code`() {
    let text = #"let fallback = weirdWords.first(where: { $0.hasPrefix("q") }) ?? "nothing""#

    let normalized = TextNormalizer.normalizeCodeHeavyLines(
        text,
        format: .source(.swift),
    )

    #expect(normalized.contains("open brace"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func `spiral prone words are spelled out`() {
    let text = "Also say chrommmaticallly and qqqwweerrtyy once."

    let normalized = TextNormalizer.normalizeSpiralProneWords(text)

    #expect(normalized.contains("c h r o m m m a t i c a l l l y"))
    #expect(normalized.contains("q q q w w e e r r t y y"))
}
