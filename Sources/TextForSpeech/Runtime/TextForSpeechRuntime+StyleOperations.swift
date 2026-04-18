import Foundation

// MARK: - Runtime Style Operations

public extension TextForSpeech.Runtime.Style {
    func getActive() -> TextForSpeech.BuiltInProfileStyle {
        runtime.builtInStyle
    }

    func list() -> [Option] {
        TextForSpeech.BuiltInProfileStyle.allCases.map(Self.option(for:))
    }

    func setActive(to style: TextForSpeech.BuiltInProfileStyle) throws {
        runtime.builtInStyle = style
        try runtime.persistCurrentState()
    }

    private static func option(for style: TextForSpeech.BuiltInProfileStyle) -> Option {
        let summary = switch style {
            case .balanced:
                "Balanced spoken-code defaults for everyday developer text."
            case .compact:
                "Keeps source-like text more visual and less expanded."
            case .explicit:
                "Uses more verbose code narration for maximum clarity."
        }

        return Option(style: style, summary: summary)
    }
}
