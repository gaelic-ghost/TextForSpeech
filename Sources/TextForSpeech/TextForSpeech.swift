import Foundation
import NaturalLanguage
import Observation
import RegexBuilder

// MARK: - Namespace

public enum TextForSpeech {
    // MARK: Context

    public struct Context: Codable, Sendable, Equatable {
        public let cwd: String?
        public let repoRoot: String?
        public let format: Format?

        public init(
            cwd: String? = nil,
            repoRoot: String? = nil,
            format: Format? = nil
        ) {
            self.cwd = Context.normalizedPath(cwd)
            self.repoRoot = Context.normalizedPath(repoRoot)
            self.format = format
        }

        private static func normalizedPath(_ path: String?) -> String? {
            guard let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }

            let standardized = NSString(string: trimmed).standardizingPath
            return standardized.isEmpty ? nil : standardized
        }
    }

    // MARK: Format

    public enum Format: String, Codable, CaseIterable, Sendable, Hashable {
        case plain = "plain_text"
        case markdown
        case html
        case source = "source_code"
        case swift = "swift_source"
        case python = "python_source"
        case rust = "rust_source"
        case log
        case cli = "cli_output"
        case list

        public func matches(_ other: Self) -> Bool {
            if self == other {
                return true
            }

            switch (self, other) {
            case (.source, .swift), (.source, .python), (.source, .rust):
                return true
            default:
                return false
            }
        }
    }

    // MARK: Replacement

    public struct Replacement: Codable, Sendable, Equatable, Identifiable {
        public enum Match: String, Codable, Sendable {
            case phrase = "exact_phrase"
            case token = "whole_token"
        }

        public enum Phase: String, Codable, Sendable {
            case beforeNormalization = "before_built_ins"
            case afterNormalization = "after_built_ins"
        }

        public let id: String
        public let text: String
        public let replacement: String
        public let match: Match
        public let phase: Phase
        public let isCaseSensitive: Bool
        public let formats: Set<Format>
        public let priority: Int

        public init(
            _ text: String,
            with replacement: String,
            id: String = UUID().uuidString,
            as match: Match = .phrase,
            in phase: Phase = .beforeNormalization,
            caseSensitive isCaseSensitive: Bool = false,
            for formats: Set<Format> = [],
            priority: Int = 0
        ) {
            self.id = id
            self.text = text
            self.replacement = replacement
            self.match = match
            self.phase = phase
            self.isCaseSensitive = isCaseSensitive
            self.formats = formats
            self.priority = priority
        }

        public func applies(to format: Format) -> Bool {
            guard !formats.isEmpty else { return true }
            return formats.contains(where: { $0.matches(format) })
        }
    }

    // MARK: Profile

    public struct Profile: Codable, Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let replacements: [Replacement]

        public init(
            id: String = "default",
            name: String = "Default",
            replacements: [Replacement] = []
        ) {
            self.id = id
            self.name = name
            self.replacements = replacements
        }

        public func replacements(
            for phase: Replacement.Phase,
            in format: Format
        ) -> [Replacement] {
            replacements
                .filter { $0.phase == phase && $0.applies(to: format) }
                .sorted {
                    if $0.priority == $1.priority {
                        return $0.id < $1.id
                    }
                    return $0.priority > $1.priority
                }
        }

        public func merged(with custom: Self) -> Self {
            Self(
                id: custom.id,
                name: custom.name,
                replacements: replacements + custom.replacements
            )
        }

        public func replacement(id: String) -> Replacement? {
            replacements.first { $0.id == id }
        }

        public func named(_ name: String) -> Self {
            Self(id: id, name: name, replacements: replacements)
        }

        public func adding(_ replacement: Replacement) -> Self {
            Self(id: id, name: name, replacements: replacements + [replacement])
        }

        public func replacing(_ replacement: Replacement) throws -> Self {
            guard replacements.contains(where: { $0.id == replacement.id }) else {
                throw TextForSpeech.RuntimeError.replacementNotFound(
                    replacement.id,
                    profileID: id
                )
            }

            return Self(
                id: id,
                name: name,
                replacements: replacements.map { existing in
                    existing.id == replacement.id ? replacement : existing
                }
            )
        }

        public func removingReplacement(id replacementID: String) throws -> Self {
            guard replacements.contains(where: { $0.id == replacementID }) else {
                throw TextForSpeech.RuntimeError.replacementNotFound(
                    replacementID,
                    profileID: id
                )
            }

            return Self(
                id: id,
                name: name,
                replacements: replacements.filter { $0.id != replacementID }
            )
        }
    }

    // MARK: Persistence

    public struct PersistedState: Codable, Sendable, Equatable {
        public let version: Int
        public let customProfile: Profile
        public let profiles: [String: Profile]

        public init(
            version: Int = 1,
            customProfile: Profile,
            profiles: [String: Profile]
        ) {
            self.version = version
            self.customProfile = customProfile
            self.profiles = profiles
        }
    }

    public enum PersistenceError: Swift.Error, Sendable, Equatable, LocalizedError {
        case missingPersistenceURL
        case unsupportedPersistedStateVersion(Int)
        case couldNotRead(URL, String)
        case couldNotDecode(URL, String)
        case couldNotCreateDirectory(URL, String)
        case couldNotWrite(URL, String)

        public var errorDescription: String? {
            switch self {
            case .missingPersistenceURL:
                "TextForSpeech could not load or save profiles because no persistence URL was configured for this runtime."
            case .unsupportedPersistedStateVersion(let version):
                "TextForSpeech could not load the persisted profile state because archive version \(version) is not supported by this build."
            case .couldNotRead(let url, let details):
                "TextForSpeech could not read persisted profiles from '\(url.path)'. \(details)"
            case .couldNotDecode(let url, let details):
                "TextForSpeech could not decode persisted profiles from '\(url.path)'. \(details)"
            case .couldNotCreateDirectory(let url, let details):
                "TextForSpeech could not create the directory for persisted profiles at '\(url.path)'. \(details)"
            case .couldNotWrite(let url, let details):
                "TextForSpeech could not write persisted profiles to '\(url.path)'. \(details)"
            }
        }
    }

    public enum RuntimeError: Swift.Error, Sendable, Equatable, LocalizedError {
        case profileAlreadyExists(String)
        case profileNotFound(String)
        case replacementNotFound(String, profileID: String)

        public var errorDescription: String? {
            switch self {
            case .profileAlreadyExists(let id):
                "TextForSpeech could not create profile '\(id)' because a stored profile with that identifier already exists."
            case .profileNotFound(let id):
                "TextForSpeech could not find a stored profile named '\(id)'."
            case .replacementNotFound(let replacementID, let profileID):
                "TextForSpeech could not find replacement '\(replacementID)' in profile '\(profileID)'."
            }
        }
    }

    // MARK: Forensics

    public struct ForensicFeatures: Sendable, Equatable {
        public let originalCharacterCount: Int
        public let normalizedCharacterCount: Int
        public let normalizedCharacterDelta: Int
        public let originalParagraphCount: Int
        public let normalizedParagraphCount: Int
        public let markdownHeaderCount: Int
        public let fencedCodeBlockCount: Int
        public let inlineCodeSpanCount: Int
        public let markdownLinkCount: Int
        public let urlCount: Int
        public let filePathCount: Int
        public let dottedIdentifierCount: Int
        public let camelCaseTokenCount: Int
        public let snakeCaseTokenCount: Int
        public let objcSymbolCount: Int
        public let repeatedLetterRunCount: Int
    }

    public enum SectionKind: String, Sendable, Equatable {
        case markdownHeader = "markdown_header"
        case paragraph
        case fullRequest = "full_request"
    }

    public struct Section: Sendable, Equatable {
        public let index: Int
        public let title: String
        public let kind: SectionKind
        public let originalCharacterCount: Int
        public let normalizedCharacterCount: Int
        public let normalizedCharacterShare: Double
    }

    public struct SectionWindow: Sendable, Equatable {
        public let section: Section
        public let estimatedStartMS: Int
        public let estimatedEndMS: Int
        public let estimatedDurationMS: Int
        public let estimatedStartChunk: Int
        public let estimatedEndChunk: Int
    }

    // MARK: Public API

    public static func normalize(
        _ text: String,
        context: Context? = nil,
        profile: Profile = .default,
        as format: Format? = nil
    ) -> String {
        TextNormalizer.normalize(
            text,
            context: context,
            profile: .base.merged(with: profile),
            format: format
        )
    }

    public static func detectFormat(in text: String) -> Format {
        TextNormalizer.detectFormat(in: text)
    }

    public static func forensicFeatures(
        originalText: String,
        normalizedText: String
    ) -> ForensicFeatures {
        TextNormalizer.forensicFeatures(originalText: originalText, normalizedText: normalizedText)
    }

    public static func sections(originalText: String) -> [Section] {
        TextNormalizer.sections(originalText: originalText)
    }

    public static func sectionWindows(
        originalText: String,
        totalDurationMS: Int,
        totalChunkCount: Int
    ) -> [SectionWindow] {
        TextNormalizer.sectionWindows(
            originalText: originalText,
            totalDurationMS: totalDurationMS,
            totalChunkCount: totalChunkCount
        )
    }

    public static func words(in text: String) -> [String] {
        TextNormalizer.naturalLanguageWords(in: text)
    }
}

public extension TextForSpeech.Profile {
    static let base = TextForSpeech.Profile(id: "base", name: "Base")
    static let `default` = TextForSpeech.Profile()
}

// MARK: - Runtime

@Observable
public final class TextForSpeechRuntime {
    private enum Persistence {
        static let currentVersion = 1
    }

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

    public func addReplacement(
        _ replacement: TextForSpeech.Replacement,
        toProfileNamed id: String? = nil
    ) throws -> TextForSpeech.Profile {
        let updatedProfile = try mutableProfile(named: id).adding(replacement)
        setProfile(updatedProfile, named: id)
        return updatedProfile
    }

    public func replaceReplacement(
        _ replacement: TextForSpeech.Replacement,
        inProfileNamed id: String? = nil
    ) throws -> TextForSpeech.Profile {
        let updatedProfile = try mutableProfile(named: id).replacing(replacement)
        setProfile(updatedProfile, named: id)
        return updatedProfile
    }

    public func removeReplacement(
        id replacementID: String,
        fromProfileNamed profileID: String? = nil
    ) throws -> TextForSpeech.Profile {
        let updatedProfile = try mutableProfile(named: profileID).removingReplacement(id: replacementID)
        setProfile(updatedProfile, named: profileID)
        return updatedProfile
    }

    public func reset() {
        customProfile = .default
    }

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

    private func mutableProfile(named id: String?) throws -> TextForSpeech.Profile {
        guard let id else { return customProfile }
        guard let profile = profiles[id] else {
            throw TextForSpeech.RuntimeError.profileNotFound(id)
        }
        return profile
    }

    private func setProfile(_ profile: TextForSpeech.Profile, named id: String?) {
        guard let id else {
            customProfile = profile
            return
        }
        profiles[id] = profile
    }
}

// MARK: - Normalizer

enum TextNormalizer {
    typealias NormalizationPass = (String) -> String
    typealias ContextualNormalizationPass =
        (String, TextForSpeech.Context?, TextForSpeech.Profile, TextForSpeech.Format) -> String

    private static var codeMarkerRegex: Regex<Substring> {
        Regex {
            ChoiceOf {
                "```"
                "`"
                "->"
                "=>"
                "::"
                "?."
                "??"
                "&&"
                "||"
                "=="
                "!="
                "{"
                "}"
                "</"
                "/>"
                "func "
                "let "
                "var "
                "const "
                "class "
                "struct "
                "enum "
                "return "
            }
        }
    }

    private static var normalizationPasses: [ContextualNormalizationPass] {
        [
            { text, _, _, _ in normalizeFencedCodeBlocks(text) },
            { text, _, _, _ in normalizeInlineCodeSpans(text) },
            { text, _, _, _ in normalizeMarkdownLinks(text) },
            { text, _, _, _ in normalizeURLs(text) },
            { text, _, _, _ in normalizeStandaloneGaleAliases(text) },
            normalizeFilePaths,
            { text, _, _, _ in normalizeDottedIdentifiers(text) },
            { text, _, _, _ in normalizeSnakeCaseIdentifiers(text) },
            { text, _, _, _ in normalizeDashedIdentifiers(text) },
            { text, _, _, _ in normalizeCamelCaseIdentifiers(text) },
            { text, _, _, _ in normalizeCodeHeavyLines(text) },
            { text, _, _, _ in normalizeSpiralProneWords(text) },
            { text, _, _, _ in collapseWhitespace(text) },
        ]
    }

    // MARK: Public API

    static func normalize(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.Format? = nil
    ) -> String {
        let format = format ?? context?.format ?? detectFormat(in: text)
        let seeded = applyReplacementRules(
            canonicalize(text),
            profile: profile,
            format: format,
            phase: .beforeNormalization
        )
        let normalized = normalizationPasses.reduce(seeded) { partial, pass in
            pass(partial, context, profile, format)
        }
        let finalized = collapseWhitespace(
            applyReplacementRules(
                normalized,
                profile: profile,
                format: format,
                phase: .afterNormalization
            )
        )
        return finalized.isEmpty ? text : finalized
    }

    static func forensicFeatures(
        originalText: String,
        normalizedText: String
    ) -> TextForSpeech.ForensicFeatures {
        let tokens = candidateTokens(in: originalText)

        return TextForSpeech.ForensicFeatures(
            originalCharacterCount: originalText.count,
            normalizedCharacterCount: normalizedText.count,
            normalizedCharacterDelta: normalizedText.count - originalText.count,
            originalParagraphCount: paragraphCount(in: originalText),
            normalizedParagraphCount: paragraphCount(in: normalizedText),
            markdownHeaderCount: originalText.split(separator: "\n", omittingEmptySubsequences: false)
                .count(where: { markdownHeaderTitle(in: String($0)) != nil }),
            fencedCodeBlockCount: fencedCodeBlockBodies(in: originalText).count,
            inlineCodeSpanCount: inlineCodeBodies(in: originalText).count,
            markdownLinkCount: markdownLinks(in: originalText).count,
            urlCount: tokens.count(where: isLikelyURL),
            filePathCount: filePathFragments(in: originalText).count,
            dottedIdentifierCount: tokens.count(where: isLikelyDottedIdentifier),
            camelCaseTokenCount: tokens.count(where: isLikelyCamelCaseIdentifier),
            snakeCaseTokenCount: tokens.count(where: isLikelySnakeCaseIdentifier),
            objcSymbolCount: tokens.count(where: isLikelyObjectiveCSymbol),
            repeatedLetterRunCount: tokens.count(where: containsRepeatedLetterRun)
        )
    }

    static func sections(originalText: String) -> [TextForSpeech.Section] {
        let sections = splitSections(in: originalText)
        let weightedCounts = sections.map { max(normalize($0.text).count, 1) }
        let totalWeightedCount = max(weightedCounts.reduce(0, +), 1)

        return sections.enumerated().map { index, section in
            TextForSpeech.Section(
                index: index + 1,
                title: section.title,
                kind: section.kind,
                originalCharacterCount: section.text.count,
                normalizedCharacterCount: weightedCounts[index],
                normalizedCharacterShare: Double(weightedCounts[index]) / Double(totalWeightedCount)
            )
        }
    }

    static func sectionWindows(
        originalText: String,
        totalDurationMS: Int,
        totalChunkCount: Int
    ) -> [TextForSpeech.SectionWindow] {
        let sections = sections(originalText: originalText)
        guard !sections.isEmpty else { return [] }

        var elapsedMS = 0
        var elapsedChunks = 0

        return sections.enumerated().map { index, section in
            let isLastSection = index == sections.count - 1
            let remainingDurationMS = max(totalDurationMS - elapsedMS, 0)
            let remainingChunkCount = max(totalChunkCount - elapsedChunks, 0)
            let durationMS = isLastSection
                ? remainingDurationMS
                : min(
                    remainingDurationMS,
                    max(Int((Double(totalDurationMS) * section.normalizedCharacterShare).rounded()), 0)
                )
            let chunkCount = isLastSection
                ? remainingChunkCount
                : min(
                    remainingChunkCount,
                    max(Int((Double(totalChunkCount) * section.normalizedCharacterShare).rounded()), 0)
                )

            let window = TextForSpeech.SectionWindow(
                section: section,
                estimatedStartMS: elapsedMS,
                estimatedEndMS: elapsedMS + durationMS,
                estimatedDurationMS: durationMS,
                estimatedStartChunk: elapsedChunks,
                estimatedEndChunk: elapsedChunks + chunkCount
            )

            elapsedMS += durationMS
            elapsedChunks += chunkCount
            return window
        }
    }

    static func detectFormat(in text: String) -> TextForSpeech.Format {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plain }

        if looksLikeHTML(trimmed) {
            return .html
        }

        if looksLikeMarkdownList(trimmed) {
            return .list
        }

        if looksLikeMarkdown(trimmed) {
            return .markdown
        }

        if looksLikeSwiftSource(trimmed) {
            return .swift
        }

        if looksLikePythonSource(trimmed) {
            return .python
        }

        if looksLikeRustSource(trimmed) {
            return .rust
        }

        if looksLikeCLIOutput(trimmed) {
            return .cli
        }

        if looksLikeLogOutput(trimmed) {
            return .log
        }

        return .plain
    }
}

// MARK: - Normalization Passes

extension TextNormalizer {
    static func normalizeFencedCodeBlocks(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { return text }

        var output: [String] = []
        var bufferedCode: [String] = []
        var insideFence = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if insideFence {
                    output.append(spokenCodeBlock(bufferedCode.joined(separator: "\n")))
                    bufferedCode.removeAll(keepingCapacity: true)
                }
                insideFence.toggle()
                continue
            }

            if insideFence {
                bufferedCode.append(line)
            } else {
                output.append(line)
            }
        }

        if insideFence, !bufferedCode.isEmpty {
            output.append(spokenCodeBlock(bufferedCode.joined(separator: "\n")))
        }

        return output.joined(separator: "\n")
    }

    static func normalizeInlineCodeSpans(_ text: String) -> String {
        let bodies = inlineCodeBodies(in: text)
        guard !bodies.isEmpty else { return text }

        var result = ""
        var index = text.startIndex
        var bodyIterator = bodies.makeIterator()
        var nextBody = bodyIterator.next()

        while index < text.endIndex {
            guard text[index] == "`", let expectedBody = nextBody else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let contentStart = text.index(after: index)
            guard let closing = text[contentStart...].firstIndex(of: "`") else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let body = String(text[contentStart..<closing])
            if body == expectedBody {
                result += spokenInlineCode(body)
                index = text.index(after: closing)
                nextBody = bodyIterator.next()
            } else {
                result.append(text[index])
                index = text.index(after: index)
            }
        }

        return result
    }

    static func normalizeMarkdownLinks(_ text: String) -> String {
        let links = markdownLinks(in: text)
        guard !links.isEmpty else { return text }

        var result = ""
        var cursor = text.startIndex

        for link in links {
            result += text[cursor..<link.fullRange.lowerBound]
            let label = link.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let destination = link.destination.trimmingCharacters(in: .whitespacesAndNewlines)

            if label.isEmpty {
                result += " \(destination) "
            } else {
                result += " \(label), link \(destination) "
            }

            cursor = link.fullRange.upperBound
        }

        result += text[cursor...]
        return result
    }

    static func normalizeURLs(_ text: String) -> String {
        transformTokens(in: text) { token in
            guard isLikelyURL(token) else { return nil }
            return spokenURL(token)
        }
    }

    static func normalizeStandaloneGaleAliases(_ text: String) -> String {
        transformTokens(in: text) { token in
            standaloneGaleAlias(for: token)
        }
    }

    static func normalizeFilePaths(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        profile _: TextForSpeech.Profile = .default,
        format _: TextForSpeech.Format = .plain
    ) -> String {
        transformTokens(in: text) { token in
            guard isLikelyFilePath(token) else { return nil }
            return spokenPath(token, context: context)
        }
    }

    static func normalizeDottedIdentifiers(_ text: String) -> String {
        transformTokens(in: text) { token in
            guard isLikelyDottedIdentifier(token) else { return nil }
            return spokenIdentifier(token)
        }
    }

    static func normalizeSnakeCaseIdentifiers(_ text: String) -> String {
        transformTokens(in: text) { token in
            guard isLikelySnakeCaseIdentifier(token) else { return nil }
            return spokenIdentifier(token)
        }
    }

    static func normalizeDashedIdentifiers(_ text: String) -> String {
        transformTokens(in: text) { token in
            guard isLikelyDashedIdentifier(token) else { return nil }
            return spokenIdentifier(token)
        }
    }

    static func normalizeCamelCaseIdentifiers(_ text: String) -> String {
        transformTokens(in: text) { token in
            guard isLikelyCamelCaseIdentifier(token) else { return nil }
            return spokenIdentifier(token)
        }
    }

    static func normalizeCodeHeavyLines(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return lines.map { line in
            isLikelyCodeLine(line) ? spokenCode(line) : line
        }.joined(separator: "\n")
    }

    static func normalizeSpiralProneWords(_ text: String) -> String {
        let tokens = naturalLanguageTokenRanges(in: text)
        guard !tokens.isEmpty else { return text }

        var result = ""
        var cursor = text.startIndex

        for range in tokens {
            result += text[cursor..<range.lowerBound]
            let token = String(text[range])
            result += containsRepeatedLetterRun(token) ? spelledOut(token) : token
            cursor = range.upperBound
        }

        result += text[cursor...]
        return result
    }

    static func looksLikeHTML(_ text: String) -> Bool {
        text.contains(/<([A-Za-z][A-Za-z0-9:-]*)(\s[^>]*)?>/) && text.contains("</")
    }

    static func looksLikeMarkdownList(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let listLineCount = lines.count { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("- ")
                || trimmed.hasPrefix("* ")
                || trimmed.hasPrefix("+ ")
                || trimmed.firstMatch(of: /^\d+\.\s+/) != nil
        }

        return listLineCount >= 2
    }

    static func looksLikeMarkdown(_ text: String) -> Bool {
        text.contains("```")
            || text.split(separator: "\n", omittingEmptySubsequences: false)
                .contains(where: { markdownHeaderTitle(in: String($0)) != nil })
            || !markdownLinks(in: text).isEmpty
            || !inlineCodeBodies(in: text).isEmpty
    }

    static func looksLikeSwiftSource(_ text: String) -> Bool {
        text.contains("import Foundation")
            || text.contains("import SwiftUI")
            || text.contains("func ")
            || text.contains("struct ")
            || text.contains("enum ")
            || text.contains("actor ")
            || text.contains("let ")
    }

    static func looksLikePythonSource(_ text: String) -> Bool {
        text.contains("def ")
            || text.contains("import ")
            || text.contains("from ")
            || text.contains("self.")
            || text.contains("print(")
    }

    static func looksLikeRustSource(_ text: String) -> Bool {
        text.contains("fn ")
            || text.contains("let mut ")
            || text.contains("impl ")
            || text.contains("use ")
            || text.contains("pub struct ")
    }

    static func looksLikeCLIOutput(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let promptLikeLines = lines.count { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("$ ")
                || trimmed.hasPrefix("> ")
                || trimmed.hasPrefix("% ")
                || trimmed.firstMatch(of: /^[A-Za-z0-9_.-]+@\S+[:~]/) != nil
        }

        return promptLikeLines >= 1
    }

    static func looksLikeLogOutput(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let logLineCount = lines.count { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.firstMatch(of: /^\d{4}-\d{2}-\d{2}[ T]/) != nil
                || trimmed.contains(" ERROR ")
                || trimmed.contains(" WARN ")
                || trimmed.contains(" INFO ")
                || trimmed.contains("[error]")
                || trimmed.contains("[warn]")
                || trimmed.contains("[info]")
        }

        return logLineCount >= 1
    }
}

// MARK: - Speech Conversion

extension TextNormalizer {
    static func spokenCode(_ text: String) -> String {
        let replacements: [(String, String)] = [
            ("\n", ". "),
            ("->", " returns "),
            ("=>", " maps to "),
            ("===", " strictly equals "),
            ("!==", " not strictly equals "),
            ("==", " equals equals "),
            ("!=", " not equals "),
            ("&&", " and "),
            ("||", " or "),
            ("::", " double colon "),
            ("?.", " optional chaining "),
            ("??", " nil coalescing "),
            ("...", " ellipsis "),
            ("_", " "),
            ("#", " hash "),
            ("*", " star "),
            ("{", " open brace "),
            ("}", " close brace "),
            ("[", " open bracket "),
            ("]", " close bracket "),
            ("(", " open parenthesis "),
            (")", " close parenthesis "),
            ("<", " less than "),
            (">", " greater than "),
            ("/", " slash "),
            ("\\", " backslash "),
            (":", " colon "),
            (";", " semicolon "),
            ("=", " equals "),
        ]

        let spoken = replacements.reduce(text) { partial, replacement in
            partial.replacingOccurrences(of: replacement.0, with: replacement.1)
        }

        return collapseWhitespace(insertWordBreaks(in: spoken))
    }

    static func spokenPath(_ text: String, context: TextForSpeech.Context? = nil) -> String {
        let contextualPath = contextualizedPath(text, context: context)
        var segments: [String] = []
        var buffer = ""
        var remainder = contextualPath.path[...]

        if let spokenContextPrefix = contextualPath.spokenContextPrefix {
            segments.append(spokenContextPrefix)
        } else if let alias = aliasedPathPrefix(in: contextualPath.path) {
            segments.append(alias.spokenName)
            remainder = contextualPath.path[alias.range.upperBound...]
        }

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            segments.append(spokenSegment(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        for character in remainder {
            switch character {
            case "~":
                flushBuffer()
                segments.append("home")
            case "/":
                flushBuffer()
                if !segments.isEmpty {
                    segments.append("slash")
                }
            case "\\":
                flushBuffer()
                segments.append("backslash")
            case ".":
                flushBuffer()
                segments.append("dot")
            case "_":
                flushBuffer()
                segments.append(" ")
            case "-":
                flushBuffer()
                segments.append(" ")
            default:
                buffer.append(character)
            }
        }

        flushBuffer()
        return collapseWhitespace(segments.joined(separator: " "))
    }

    static func spokenURL(_ text: String) -> String {
        guard let schemeSeparator = text.range(of: "://") else {
            return spokenPath(text)
        }

        let scheme = text[..<schemeSeparator.lowerBound].lowercased()
        var remainder = String(text[schemeSeparator.upperBound...])

        if ["http", "https"].contains(scheme) {
            if remainder.hasPrefix("www.") {
                remainder.removeFirst(4)
            }

            return spokenPath(remainder)
        }

        return collapseWhitespace(
            "\(spokenSegment(String(scheme))) colon slash slash \(spokenPath(remainder))"
        )
    }

    static func spokenIdentifier(_ text: String) -> String {
        var parts: [String] = []
        var buffer = ""

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            parts.append(spokenSegment(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        for character in text {
            switch character {
            case ".":
                flushBuffer()
                parts.append("dot")
            case "_":
                flushBuffer()
                parts.append(" ")
            case "-":
                flushBuffer()
                parts.append(" ")
            default:
                buffer.append(character)
            }
        }

        flushBuffer()
        return collapseWhitespace(parts.joined(separator: " "))
    }
}

// MARK: - Formatting

extension TextNormalizer {
    static func canonicalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: " ")
    }

    static func collapseWhitespace(_ text: String) -> String {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            }

        var rebuilt = ""
        var blankLineCount = 0

        for line in lines {
            if line.isEmpty {
                blankLineCount += 1
                continue
            }

            if blankLineCount > 0, !rebuilt.isEmpty {
                rebuilt += ". "
            } else if !rebuilt.isEmpty, !rebuilt.hasSuffix(" ") {
                rebuilt += " "
            }

            rebuilt += line
            blankLineCount = 0
        }

        return rebuilt
            .replacingOccurrences(
                of: #"\s+([,.;:?!])"#,
                with: "$1",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Section Splitting

extension TextNormalizer {
    private struct SectionCandidate {
        let title: String
        let kind: TextForSpeech.SectionKind
        let text: String
    }

    private static func splitSections(in text: String) -> [SectionCandidate] {
        let headerSections = splitMarkdownHeaderSections(in: text)
        if !headerSections.isEmpty {
            return headerSections
        }

        let paragraphSections = splitParagraphSections(in: text)
        if !paragraphSections.isEmpty {
            return paragraphSections
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return [
            SectionCandidate(
                title: "Full Request",
                kind: .fullRequest,
                text: trimmed
            )
        ]
    }

    private static func splitMarkdownHeaderSections(in text: String) -> [SectionCandidate] {
        let lines = text.components(separatedBy: .newlines)
        var sections: [SectionCandidate] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func flushCurrentSection() {
            guard let currentTitle else { return }
            let sectionText = currentLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sectionText.isEmpty else { return }
            sections.append(
                SectionCandidate(
                    title: currentTitle,
                    kind: .markdownHeader,
                    text: sectionText
                )
            )
        }

        for line in lines {
            if let title = markdownHeaderTitle(in: line) {
                flushCurrentSection()
                currentTitle = title
                currentLines = [line]
            } else if currentTitle != nil {
                currentLines.append(line)
            }
        }

        flushCurrentSection()
        return sections
    }

    private static func splitParagraphSections(in text: String) -> [SectionCandidate] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, paragraph in
                SectionCandidate(
                    title: "Paragraph \(index + 1)",
                    kind: .paragraph,
                    text: paragraph
                )
            }
    }

    static func markdownHeaderTitle(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "#" else { return nil }

        let title = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }
}

// MARK: - Parsing Utilities

extension TextNormalizer {
    private struct MarkdownLinkMatch {
        let fullRange: Range<String.Index>
        let label: String
        let destination: String
    }

    static func fencedCodeBlockBodies(in text: String) -> [String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var bodies: [String] = []
        var buffer: [String] = []
        var insideFence = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if insideFence {
                    bodies.append(buffer.joined(separator: "\n"))
                    buffer.removeAll(keepingCapacity: true)
                }
                insideFence.toggle()
                continue
            }

            if insideFence {
                buffer.append(line)
            }
        }

        if insideFence, !buffer.isEmpty {
            bodies.append(buffer.joined(separator: "\n"))
        }

        return bodies
    }

    static func inlineCodeBodies(in text: String) -> [String] {
        var bodies: [String] = []
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "`" else {
                index = text.index(after: index)
                continue
            }

            let contentStart = text.index(after: index)
            guard let closing = text[contentStart...].firstIndex(of: "`") else {
                break
            }

            bodies.append(String(text[contentStart..<closing]))
            index = text.index(after: closing)
        }

        return bodies
    }

    private static func markdownLinks(in text: String) -> [MarkdownLinkMatch] {
        var matches: [MarkdownLinkMatch] = []
        var cursor = text.startIndex

        while cursor < text.endIndex {
            guard let labelStart = text[cursor...].firstIndex(of: "[") else { break }
            guard let labelEnd = text[labelStart...].firstRange(of: "](")?.lowerBound else {
                cursor = text.index(after: labelStart)
                continue
            }

            let destinationStart = text.index(labelEnd, offsetBy: 2)
            guard let destinationEnd = text[destinationStart...].firstIndex(of: ")") else {
                cursor = text.index(after: labelStart)
                continue
            }

            let fullRange = labelStart..<text.index(after: destinationEnd)
            matches.append(
                MarkdownLinkMatch(
                    fullRange: fullRange,
                    label: String(text[text.index(after: labelStart)..<labelEnd]),
                    destination: String(text[destinationStart..<destinationEnd])
                )
            )
            cursor = fullRange.upperBound
        }

        return matches
    }

    static func candidateTokens(in text: String) -> [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(trimmedCandidateToken)
            .filter { !$0.isEmpty }
    }

    static func filePathFragments(in text: String) -> [String] {
        var fragments: [String] = []
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let startsTildePath = character == "~"
                && text.index(after: index) < text.endIndex
                && text[text.index(after: index)] == "/"

            guard character == "/" || startsTildePath else {
                index = text.index(after: index)
                continue
            }

            let start = index
            var end = index

            while end < text.endIndex {
                let current = text[end]
                if current.isWhitespace || "`),;\"[]{}".contains(current) {
                    break
                }
                end = text.index(after: end)
            }

            let fragment = String(text[start..<end])
            if isLikelyFilePath(fragment) {
                fragments.append(fragment)
            }

            index = end
        }

        return fragments
    }

    static func naturalLanguageTokenRanges(in text: String) -> [Range<String.Index>] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
    }

    static func naturalLanguageWords(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) }
    }
}

// MARK: - Small Helpers

extension TextNormalizer {
    private struct ContextualizedPath {
        let path: String
        let spokenContextPrefix: String?
    }

    static func paragraphCount(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        return trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    static func transformTokens(in text: String, transform: (String) -> String?) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            guard !text[index].isWhitespace else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let start = index
            while index < text.endIndex, !text[index].isWhitespace {
                index = text.index(after: index)
            }

            let rawToken = String(text[start..<index])
            result += transformedToken(rawToken, transform: transform)
        }

        return result
    }

    static func applyReplacementRules(
        _ text: String,
        profile: TextForSpeech.Profile,
        format: TextForSpeech.Format,
        phase: TextForSpeech.Replacement.Phase
    ) -> String {
        profile.replacements(for: phase, in: format).reduce(text) { partial, rule in
            applyReplacementRule(rule, to: partial)
        }
    }

    private static func applyReplacementRule(
        _ rule: TextForSpeech.Replacement,
        to text: String
    ) -> String {
        guard !rule.text.isEmpty else { return text }

        switch rule.match {
        case .phrase:
            return text.replacingOccurrences(
                of: rule.text,
                with: rule.replacement,
                options: rule.isCaseSensitive ? [] : [.caseInsensitive]
            )

        case .token:
            return transformTokens(in: text) { token in
                tokenMatches(rule.text, token: token, caseSensitive: rule.isCaseSensitive)
                    ? rule.replacement
                    : nil
            }
        }
    }

    private static func tokenMatches(_ expected: String, token: String, caseSensitive: Bool) -> Bool {
        caseSensitive
            ? token == expected
            : token.compare(expected, options: [.caseInsensitive]) == .orderedSame
    }

    static func transformedToken(_ rawToken: String, transform: (String) -> String?) -> String {
        let punctuation = CharacterSet(charactersIn: "\"'()[]{}<>.,;:!?")
        var start = rawToken.startIndex
        var end = rawToken.endIndex

        while start < end,
            rawToken[start].unicodeScalars.allSatisfy({ punctuation.contains($0) })
        {
            start = rawToken.index(after: start)
        }

        while end > start {
            let beforeEnd = rawToken.index(before: end)
            guard rawToken[beforeEnd].unicodeScalars.allSatisfy({ punctuation.contains($0) }) else {
                break
            }
            end = beforeEnd
        }

        let prefix = rawToken[..<start]
        let core = String(rawToken[start..<end])
        let suffix = rawToken[end...]

        guard !core.isEmpty, let replacement = transform(core) else {
            return rawToken
        }

        return "\(prefix)\(replacement)\(suffix)"
    }

    static func trimmedCandidateToken(_ token: String) -> String {
        let punctuation = CharacterSet(charactersIn: "\"'()[]{}<>.,;:!?")
        var start = token.startIndex
        var end = token.endIndex

        while start < end,
            token[start].unicodeScalars.allSatisfy({ punctuation.contains($0) })
        {
            start = token.index(after: start)
        }

        while end > start {
            let beforeEnd = token.index(before: end)
            guard token[beforeEnd].unicodeScalars.allSatisfy({ punctuation.contains($0) }) else {
                break
            }
            end = beforeEnd
        }

        return String(token[start..<end])
    }

    private static func aliasedPathPrefix(in text: String) -> (range: Range<String.Index>, spokenName: String)? {
        let aliases = [
            ("/Users/galew", "gale wumbo"),
            ("/Users/galem", "gale mini"),
        ]

        for (prefix, spokenName) in aliases {
            guard text.hasPrefix(prefix) else { continue }

            let prefixEnd = text.index(text.startIndex, offsetBy: prefix.count)
            let isExactMatch = prefixEnd == text.endIndex
            let continuesAsPath = !isExactMatch && text[prefixEnd] == "/"
            if isExactMatch || continuesAsPath {
                return (text.startIndex..<prefixEnd, spokenName)
            }
        }

        return nil
    }

    private static func standaloneGaleAlias(for token: String) -> String? {
        switch token.lowercased() {
        case "galew":
            "gale wumbo"
        case "galem":
            "gale mini"
        default:
            nil
        }
    }

    private static func contextualizedPath(
        _ path: String,
        context: TextForSpeech.Context?
    ) -> ContextualizedPath {
        guard path.hasPrefix("/") else {
            return ContextualizedPath(path: path, spokenContextPrefix: nil)
        }

        let standardizedPath = NSString(string: path).standardizingPath

        if let cwd = context?.cwd,
            let relativePath = relativePath(from: cwd, to: standardizedPath)
        {
            let spokenContextPrefix = relativePath.isEmpty ? "current directory" : "current directory slash"
            return ContextualizedPath(path: relativePath, spokenContextPrefix: spokenContextPrefix)
        }

        if let repoRoot = context?.repoRoot,
            let relativePath = relativePath(from: repoRoot, to: standardizedPath)
        {
            let spokenContextPrefix = relativePath.isEmpty ? "repo root" : "repo root slash"
            return ContextualizedPath(path: relativePath, spokenContextPrefix: spokenContextPrefix)
        }

        return ContextualizedPath(path: standardizedPath, spokenContextPrefix: nil)
    }

    private static func relativePath(from basePath: String, to path: String) -> String? {
        let standardizedBasePath = NSString(string: basePath).standardizingPath

        guard standardizedPathBoundaryMatches(path, prefix: standardizedBasePath) else {
            return nil
        }

        guard path.count > standardizedBasePath.count else {
            return ""
        }

        let relativeStart = path.index(path.startIndex, offsetBy: standardizedBasePath.count + 1)
        return String(path[relativeStart...])
    }

    private static func standardizedPathBoundaryMatches(_ path: String, prefix: String) -> Bool {
        guard path.hasPrefix(prefix) else { return false }
        guard path.count > prefix.count else { return true }

        let boundaryIndex = path.index(path.startIndex, offsetBy: prefix.count)
        return path[boundaryIndex] == "/"
    }

    static func isLikelyFilePath(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        guard !token.contains("://") else { return false }
        guard !token.contains("@") else { return false }

        return token.hasPrefix("/")
            || token.hasPrefix("~/")
            || (token.contains("/") && !token.contains(" "))
    }

    static func isLikelyURL(_ token: String) -> Bool {
        guard let schemeSeparator = token.range(of: "://") else { return false }
        let scheme = token[..<schemeSeparator.lowerBound]
        guard !scheme.isEmpty else { return false }
        return scheme.allSatisfy { $0.isLetter }
    }

    static func isLikelyDottedIdentifier(_ token: String) -> Bool {
        guard token.contains(".") else { return false }
        guard !isLikelyFilePath(token) else { return false }
        guard !token.contains("://") else { return false }

        let parts = token.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy(isIdentifierLike)
    }

    static func isLikelySnakeCaseIdentifier(_ token: String) -> Bool {
        guard token.contains("_") else { return false }
        let parts = token.split(separator: "_").map(String.init)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isAlphaNumeric) }
    }

    static func isLikelyDashedIdentifier(_ token: String) -> Bool {
        guard token.contains("-") else { return false }
        guard !isLikelyFilePath(token) else { return false }
        guard !token.contains("://") else { return false }

        let parts = token.split(separator: "-").map(String.init)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isAlphaNumeric) }
    }

    static func isLikelyCamelCaseIdentifier(_ token: String) -> Bool {
        guard !token.contains("."),
            !token.contains("_"),
            !token.contains("-"),
            !token.contains("/")
        else {
            return false
        }

        return hasLowerToUpperTransition(token)
    }

    static func isLikelyObjectiveCSymbol(_ token: String) -> Bool {
        if token.hasPrefix("NS"), token.dropFirst(2).first?.isUppercase == true {
            return true
        }

        guard token.contains(":") else { return false }
        return token.split(separator: ":").allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isAlphaNumeric)
        }
    }

    static func isIdentifierLike(_ token: String) -> Bool {
        !token.isEmpty && token.allSatisfy { $0.isAlphaNumeric || $0 == "_" }
    }

    static func hasLowerToUpperTransition(_ text: String) -> Bool {
        var previous: Character?

        for character in text {
            defer { previous = character }
            guard let previous else { continue }
            if previous.isLowercase, character.isUppercase {
                return true
            }
        }

        return false
    }

    static func containsRepeatedLetterRun(_ text: String) -> Bool {
        var previous: Character?
        var runLength = 1

        for character in text.lowercased() {
            guard character.isLetter else {
                previous = nil
                runLength = 1
                continue
            }

            if previous == character {
                runLength += 1
                if runLength >= 3 {
                    return true
                }
            } else {
                previous = character
                runLength = 1
            }
        }

        return false
    }

    static func spelledOut(_ text: String) -> String {
        text.map { String($0) }.joined(separator: " ")
    }

    static func spokenCodeBlock(_ body: String) -> String {
        let spoken = spokenCode(body)
        return spoken.isEmpty ? "Code sample." : "Code sample. \(spoken). End code sample."
    }

    static func spokenInlineCode(_ body: String) -> String {
        let spoken = spokenCode(body)
        return spoken.isEmpty ? " code " : " \(spoken) "
    }

    static func spokenSegment(_ text: String) -> String {
        let broken = insertWordBreaks(in: text)
        let words = naturalLanguageWords(in: broken)
        if words.isEmpty {
            return broken
        }
        return words.joined(separator: " ")
    }

    static func insertWordBreaks(in text: String) -> String {
        guard !text.isEmpty else { return text }

        var output = ""
        var previous: Character?

        for character in text {
            defer { previous = character }

            guard let previous else {
                output.append(character)
                continue
            }

            let needsBreak =
                (previous.isLowercase && character.isUppercase)
                || (previous.isLetter && character.isNumber)
                || (previous.isNumber && character.isLetter)

            if needsBreak, output.last != " " {
                output.append(" ")
            }

            output.append(character)
        }

        return output
    }

    static func isLikelyCodeLine(_ line: String) -> Bool {
        let punctuation = line.filter { "{}[]()<>/\\=_*#|~:;.`-".contains($0) }.count
        let letters = line.filter(\.isLetter).count
        let hasStructuredMarker =
            line.firstMatch(of: codeMarkerRegex) != nil
            || line.contains("[")
            || line.contains("]")
            || line.contains("@property")

        return punctuation >= 6 && (punctuation * 2 >= max(letters, 4) || hasStructuredMarker)
    }
}

extension Character {
    fileprivate var isAlphaNumeric: Bool { isLetter || isNumber }
}
