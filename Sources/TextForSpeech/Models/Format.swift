// MARK: - Format

public extension TextForSpeech {
    enum TextFormat: String, Codable, CaseIterable, Sendable, Hashable {
        case plain = "plain_text"
        case markdown
        case html
        case log
        case cli = "cli_output"
        case list
    }

    enum SourceFormat: String, Codable, CaseIterable, Sendable, Hashable {
        case generic = "source_code"
        case swift = "swift_source"
        case python = "python_source"
        case rust = "rust_source"

        public func matches(_ other: Self) -> Bool {
            self == .generic || self == other
        }
    }

    enum Format: String, Codable, CaseIterable, Sendable, Hashable {
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

        var textFormat: TextFormat? {
            switch self {
            case .plain: .plain
            case .markdown: .markdown
            case .html: .html
            case .log: .log
            case .cli: .cli
            case .list: .list
            case .source, .swift, .python, .rust: nil
            }
        }

        var sourceFormat: SourceFormat? {
            switch self {
            case .source: .generic
            case .swift: .swift
            case .python: .python
            case .rust: .rust
            case .plain, .markdown, .html, .log, .cli, .list: nil
            }
        }
    }
}

public extension TextForSpeech.Format {
    init(_ format: TextForSpeech.TextFormat) {
        switch format {
        case .plain: self = .plain
        case .markdown: self = .markdown
        case .html: self = .html
        case .log: self = .log
        case .cli: self = .cli
        case .list: self = .list
        }
    }

    init(_ format: TextForSpeech.SourceFormat) {
        switch format {
        case .generic: self = .source
        case .swift: self = .swift
        case .python: self = .python
        case .rust: self = .rust
        }
    }
}

// MARK: - Internal Normalization Format

enum NormalizationFormat: Sendable, Hashable {
    case text(TextForSpeech.TextFormat)
    case source(TextForSpeech.SourceFormat)

    init(_ format: TextForSpeech.Format) {
        if let textFormat = format.textFormat {
            self = .text(textFormat)
        } else {
            self = .source(format.sourceFormat ?? .generic)
        }
    }
}
