import Foundation

// MARK: - Namespace

public enum TextForSpeech {}

extension TextForSpeech {
    static func mergedBuiltInProfile(with profile: Profile) -> Profile {
        Profile.base.merged(with: profile)
    }
}
