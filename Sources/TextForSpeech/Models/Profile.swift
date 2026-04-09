// MARK: - Profile

public extension TextForSpeech {
    struct Profile: Codable, Sendable, Equatable, Identifiable {
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
            in format: TextFormat
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

        public func replacements(
            for phase: Replacement.Phase,
            in format: SourceFormat
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
}

// MARK: - Built-in Profiles

public extension TextForSpeech.Profile {
    static let base = TextForSpeech.Profile(
        id: "base",
        name: "Base",
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
            TextForSpeech.Replacement(
                id: "base-repeated-letter-run",
                matching: .token(.repeatedLetterRun),
                using: .spellOut,
                priority: -100
            ),
        ]
    )
    static let `default` = TextForSpeech.Profile()
}
