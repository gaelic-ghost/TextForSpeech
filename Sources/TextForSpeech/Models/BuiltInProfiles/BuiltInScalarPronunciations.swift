// MARK: - Built-In Scalar Pronunciations

public extension TextForSpeech.Profile {
    /// Whole-token scalar pronunciations for terse typed-width forms that are
    /// consistently unpleasant for speech models to interpret raw.
    static let scalarPronunciationReplacements: [TextForSpeech.Replacement] = [
        TextForSpeech.Replacement("f16", with: "float sixteen", id: "base-f16", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("f32", with: "float thirty two", id: "base-f32", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("f64", with: "float sixty four", id: "base-f64", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("i8", with: "signed integer eight", id: "base-i8", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("i16", with: "signed integer sixteen", id: "base-i16", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("i32", with: "signed integer thirty two", id: "base-i32", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("i64", with: "signed integer sixty four", id: "base-i64", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("u8", with: "unsigned integer eight", id: "base-u8", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("u16", with: "unsigned integer sixteen", id: "base-u16", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("u32", with: "unsigned integer thirty two", id: "base-u32", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("u64", with: "unsigned integer sixty four", id: "base-u64", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("isize", with: "signed integer size", id: "base-isize", matching: .wholeToken, priority: -10),
        TextForSpeech.Replacement("usize", with: "unsigned integer size", id: "base-usize", matching: .wholeToken, priority: -10),
    ]
}
