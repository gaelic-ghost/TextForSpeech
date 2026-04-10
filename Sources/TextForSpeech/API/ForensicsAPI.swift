import Foundation

// MARK: - Forensics API

public extension TextForSpeech {
    enum Forensics {}
}

public extension TextForSpeech.Forensics {
    static func words(in text: String) -> [String] {
        TextNormalizer.naturalLanguageWords(in: text)
    }
}
