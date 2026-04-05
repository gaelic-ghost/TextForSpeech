// MARK: - Format

public extension TextForSpeech {
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
    }
}
