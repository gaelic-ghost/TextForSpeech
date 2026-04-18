import Foundation

public extension TextForSpeech.Runtime.Profiles {
    func setActive(id: String) throws {
        guard runtime.storedCustomProfilesByID[id] != nil else {
            throw TextForSpeech.RuntimeError.profileNotFound(id)
        }

        runtime.activeCustomProfileID = id
        try runtime.persistCurrentState()
    }

    @discardableResult
    func create(
        name: String,
    ) throws -> Details {
        let id = runtime.makeProfileID(from: name)
        guard runtime.storedCustomProfilesByID[id] == nil else {
            throw TextForSpeech.RuntimeError.profileAlreadyExists(id)
        }

        let profile = TextForSpeech.Profile(
            id: id,
            name: name,
        )
        runtime.storedCustomProfilesByID[id] = profile
        try runtime.persistCurrentState()
        return Details(
            profileID: id,
            summary: Summary(profile: profile),
            replacements: profile.replacements,
        )
    }

    @discardableResult
    func rename(
        profile id: String,
        to name: String,
    ) throws -> Details {
        let updatedProfile = try runtime.storedCustomProfile(id: id).named(name)
        runtime.storedCustomProfilesByID[id] = updatedProfile
        try runtime.persistCurrentState()
        return Details(
            profileID: id,
            summary: Summary(profile: updatedProfile),
            replacements: updatedProfile.replacements,
        )
    }

    func delete(id: String) throws {
        runtime.storedCustomProfilesByID.removeValue(forKey: id)
        try runtime.repairProfileState(persistIfChanged: true)
    }

    @discardableResult
    func addReplacement(
        _ replacement: TextForSpeech.Replacement,
    ) throws -> Details {
        let updatedProfile = runtime.activeCustomProfile().adding(replacement)
        runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
        try runtime.persistCurrentState()
        return Details(
            profileID: runtime.activeCustomProfileID,
            summary: Summary(profile: updatedProfile),
            replacements: updatedProfile.replacements,
        )
    }

    @discardableResult
    func addReplacement(
        _ replacement: TextForSpeech.Replacement,
        toProfile id: String,
    ) throws -> Details {
        let updatedProfile = try runtime.storedCustomProfile(id: id).adding(replacement)
        runtime.storedCustomProfilesByID[id] = updatedProfile
        try runtime.persistCurrentState()
        return Details(
            profileID: id,
            summary: Summary(profile: updatedProfile),
            replacements: updatedProfile.replacements,
        )
    }

    @discardableResult
    func patchReplacement(
        _ replacement: TextForSpeech.Replacement,
    ) throws -> Details {
        let updatedProfile = try runtime.activeCustomProfile().replacing(replacement)
        runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
        try runtime.persistCurrentState()
        return Details(
            profileID: runtime.activeCustomProfileID,
            summary: Summary(profile: updatedProfile),
            replacements: updatedProfile.replacements,
        )
    }

    @discardableResult
    func patchReplacement(
        _ replacement: TextForSpeech.Replacement,
        inProfile id: String,
    ) throws -> Details {
        let updatedProfile = try runtime.storedCustomProfile(id: id).replacing(replacement)
        runtime.storedCustomProfilesByID[id] = updatedProfile
        try runtime.persistCurrentState()
        return Details(
            profileID: id,
            summary: Summary(profile: updatedProfile),
            replacements: updatedProfile.replacements,
        )
    }

    @discardableResult
    func removeReplacement(
        id replacementID: String,
    ) throws -> Details {
        let updatedProfile = try runtime.activeCustomProfile().removingReplacement(id: replacementID)
        runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
        try runtime.persistCurrentState()
        return Details(
            profileID: runtime.activeCustomProfileID,
            summary: Summary(profile: updatedProfile),
            replacements: updatedProfile.replacements,
        )
    }

    @discardableResult
    func removeReplacement(
        id replacementID: String,
        fromProfile id: String,
    ) throws -> Details {
        let updatedProfile = try runtime.storedCustomProfile(id: id).removingReplacement(id: replacementID)
        runtime.storedCustomProfilesByID[id] = updatedProfile
        try runtime.persistCurrentState()
        return Details(
            profileID: id,
            summary: Summary(profile: updatedProfile),
            replacements: updatedProfile.replacements,
        )
    }

    func factoryReset() throws {
        runtime.activeCustomProfileID = TextForSpeech.Profile.default.id
        runtime.storedCustomProfilesByID = [TextForSpeech.Profile.default.id: .default]
        try runtime.persistCurrentState()
    }

    func reset(id: String) throws {
        let storedProfile = try runtime.storedCustomProfile(id: id)
        let resetProfile = TextForSpeech.Profile(id: storedProfile.id, name: storedProfile.name)
        runtime.storedCustomProfilesByID[id] = resetProfile
        try runtime.persistCurrentState()
    }
}
