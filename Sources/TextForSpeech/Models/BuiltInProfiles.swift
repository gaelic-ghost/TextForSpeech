// MARK: - Built-in Profiles

public extension TextForSpeech.Profile {
    static let semanticCore = TextForSpeech.Profile(
        id: "semantic-core",
        name: "Semantic Core",
        replacements: [
            TextForSpeech.Replacement(
                "galew",
                with: "gale wumbo",
                id: "base-galew",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "galem",
                with: "gale mini",
                id: "base-galem",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "f16",
                with: "float sixteen",
                id: "base-f16",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "f32",
                with: "float thirty two",
                id: "base-f32",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "f64",
                with: "float sixty four",
                id: "base-f64",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "i8",
                with: "signed integer eight",
                id: "base-i8",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "i16",
                with: "signed integer sixteen",
                id: "base-i16",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "i32",
                with: "signed integer thirty two",
                id: "base-i32",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "i64",
                with: "signed integer sixty four",
                id: "base-i64",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "u8",
                with: "unsigned integer eight",
                id: "base-u8",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "u16",
                with: "unsigned integer sixteen",
                id: "base-u16",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "u32",
                with: "unsigned integer thirty two",
                id: "base-u32",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "u64",
                with: "unsigned integer sixty four",
                id: "base-u64",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "isize",
                with: "signed integer size",
                id: "base-isize",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "usize",
                with: "unsigned integer size",
                id: "base-usize",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                id: "base-url",
                matching: .token(.url),
                using: .spokenURL,
                priority: -20
            ),
            TextForSpeech.Replacement(
                id: "base-file-path",
                matching: .token(.filePath),
                using: .spokenPath,
                priority: -30
            ),
            TextForSpeech.Replacement(
                id: "base-dotted-identifier",
                matching: .token(.dottedIdentifier),
                using: .spokenIdentifier,
                priority: -40
            ),
            TextForSpeech.Replacement(
                id: "base-snake-identifier",
                matching: .token(.snakeCaseIdentifier),
                using: .spokenIdentifier,
                priority: -50
            ),
            TextForSpeech.Replacement(
                id: "base-dashed-identifier",
                matching: .token(.dashedIdentifier),
                using: .spokenIdentifier,
                priority: -60
            ),
            TextForSpeech.Replacement(
                id: "base-camel-identifier",
                matching: .token(.camelCaseIdentifier),
                using: .spokenIdentifier,
                priority: -70
            ),
            TextForSpeech.Replacement(
                id: "base-repeated-letter-run",
                matching: .token(.repeatedLetterRun),
                using: .spellOut,
                priority: -100
            ),
        ]
    )

    static func builtInStyle(_ style: TextForSpeech.BuiltInProfileStyle) -> TextForSpeech.Profile {
        switch style {
        case .balanced:
            balancedBuiltInStyle
        case .compact:
            compactBuiltInStyle
        case .explicit:
            explicitBuiltInStyle
        }
    }

    static func builtInBase(
        style: TextForSpeech.BuiltInProfileStyle
    ) -> TextForSpeech.Profile {
        semanticCore.merged(with: builtInStyle(style))
    }

    static let base = builtInBase(style: .balanced)

    private static let balancedBuiltInStyle = TextForSpeech.Profile(
        id: "base",
        name: "Balanced Built-In Style",
        replacements: [
            TextForSpeech.Replacement(
                id: "balanced-function-call",
                matching: .token(.functionCall),
                using: .spokenFunctionCall(.balanced),
                priority: 40
            ),
            TextForSpeech.Replacement(
                id: "balanced-issue-reference",
                matching: .token(.issueReference),
                using: .spokenIssueReference(.balanced),
                priority: 30
            ),
            TextForSpeech.Replacement(
                id: "balanced-file-reference",
                matching: .token(.fileLineReference),
                using: .spokenFileReference(.balanced),
                priority: 20
            ),
            TextForSpeech.Replacement(
                id: "balanced-cli-flag",
                matching: .token(.cliFlag),
                using: .spokenCLIFlag(.balanced),
                priority: 10
            ),
            TextForSpeech.Replacement(
                id: "base-text-code-line",
                matching: .line(.codeLike),
                using: .spokenCode,
                forTextFormats: Set(TextForSpeech.TextFormat.allCases),
                priority: -80
            ),
            TextForSpeech.Replacement(
                id: "base-source-line",
                matching: .line(.nonEmpty),
                using: .spokenCode,
                forSourceFormats: [.generic],
                priority: -90
            ),
        ]
    )

    private static let compactBuiltInStyle = TextForSpeech.Profile(
        id: "compact-built-in-style",
        name: "Compact Built-In Style",
        replacements: [
            TextForSpeech.Replacement(
                id: "compact-function-call",
                matching: .token(.functionCall),
                using: .spokenFunctionCall(.compact),
                priority: 40
            ),
            TextForSpeech.Replacement(
                id: "compact-issue-reference",
                matching: .token(.issueReference),
                using: .spokenIssueReference(.compact),
                priority: 30
            ),
            TextForSpeech.Replacement(
                id: "compact-file-reference",
                matching: .token(.fileLineReference),
                using: .spokenFileReference(.compact),
                priority: 20
            ),
            TextForSpeech.Replacement(
                id: "compact-cli-flag",
                matching: .token(.cliFlag),
                using: .spokenCLIFlag(.compact),
                priority: 10
            ),
        ]
    )

    private static let explicitBuiltInStyle = TextForSpeech.Profile(
        id: "explicit-built-in-style",
        name: "Explicit Built-In Style",
        replacements: [
            TextForSpeech.Replacement(
                id: "explicit-function-call",
                matching: .token(.functionCall),
                using: .spokenFunctionCall(.explicit),
                priority: 40
            ),
            TextForSpeech.Replacement(
                id: "explicit-issue-reference",
                matching: .token(.issueReference),
                using: .spokenIssueReference(.explicit),
                priority: 30
            ),
            TextForSpeech.Replacement(
                id: "explicit-file-reference",
                matching: .token(.fileLineReference),
                using: .spokenFileReference(.explicit),
                priority: 20
            ),
            TextForSpeech.Replacement(
                id: "explicit-cli-flag",
                matching: .token(.cliFlag),
                using: .spokenCLIFlag(.explicit),
                priority: 10
            ),
            TextForSpeech.Replacement(
                id: "base-text-code-line",
                matching: .line(.codeLike),
                using: .spokenCode,
                forTextFormats: Set(TextForSpeech.TextFormat.allCases),
                priority: -80
            ),
            TextForSpeech.Replacement(
                id: "base-source-line",
                matching: .line(.nonEmpty),
                using: .spokenCode,
                forSourceFormats: [.generic],
                priority: -90
            ),
        ]
    )

    static let `default` = TextForSpeech.Profile()
}
