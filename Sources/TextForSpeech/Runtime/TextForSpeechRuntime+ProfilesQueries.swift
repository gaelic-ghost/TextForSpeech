import Foundation

public extension TextForSpeech.Runtime.Profiles {
    func getActive() -> Details {
        let profile = runtime.activeCustomProfile()
        return Details(
            profileID: runtime.activeCustomProfileID,
            summary: Summary(profile: profile),
            replacements: profile.replacements,
        )
    }

    func getEffective() -> Details {
        let profile = runtime.baseProfile.merged(with: runtime.activeCustomProfile())
        return Details(
            profileID: runtime.activeCustomProfileID,
            summary: Summary(profile: profile),
            replacements: profile.replacements,
        )
    }

    func get(id: String) throws -> Details {
        let profile = try runtime.storedCustomProfile(id: id)
        return Details(
            profileID: id,
            summary: Summary(profile: profile),
            replacements: profile.replacements,
        )
    }

    func list() -> [Summary] {
        runtime.storedCustomProfilesByID
            .values
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map(Summary.init(profile:))
    }
}
