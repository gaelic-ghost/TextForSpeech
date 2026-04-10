import Foundation

// MARK: - Runtime Profiles

public extension TextForSpeech.Runtime {
    struct Profiles {
        fileprivate let runtime: TextForSpeech.Runtime

        internal init(runtime: TextForSpeech.Runtime) {
            self.runtime = runtime
        }

        public var activeID: String {
            runtime.activeCustomProfileID
        }

        public var builtInStyle: TextForSpeech.BuiltInProfileStyle {
            runtime.builtInStyle
        }

        public func active() -> TextForSpeech.Profile {
            runtime.storedCustomProfilesByID[runtime.activeCustomProfileID]
                ?? .default
        }

        public func stored(id: String) -> TextForSpeech.Profile? {
            runtime.storedCustomProfilesByID[id]
        }

        public func list() -> [TextForSpeech.Profile] {
            runtime.storedCustomProfilesByID.values.sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }

        public func effective() -> TextForSpeech.Profile {
            runtime.baseProfile.merged(with: active())
        }

        public func effective(id: String) -> TextForSpeech.Profile? {
            stored(id: id).map { runtime.baseProfile.merged(with: $0) }
        }

        public func activate(id: String) throws {
            guard runtime.storedCustomProfilesByID[id] != nil else {
                throw TextForSpeech.RuntimeError.profileNotFound(id)
            }

            runtime.activeCustomProfileID = id
            try runtime.persistCurrentState()
        }

        public func setBuiltInStyle(_ style: TextForSpeech.BuiltInProfileStyle) throws {
            runtime.builtInStyle = style
            try runtime.persistCurrentState()
        }

        public func store(_ profile: TextForSpeech.Profile) throws {
            runtime.storedCustomProfilesByID[profile.id] = profile
            try runtime.repairProfileState(persistIfChanged: true)
        }

        @discardableResult
        public func create(
            id: String,
            name: String,
            replacements: [TextForSpeech.Replacement] = []
        ) throws -> TextForSpeech.Profile {
            guard runtime.storedCustomProfilesByID[id] == nil else {
                throw TextForSpeech.RuntimeError.profileAlreadyExists(id)
            }

            let profile = TextForSpeech.Profile(
                id: id,
                name: name,
                replacements: replacements
            )
            runtime.storedCustomProfilesByID[id] = profile
            try runtime.persistCurrentState()
            return profile
        }

        public func delete(id: String) throws {
            runtime.storedCustomProfilesByID.removeValue(forKey: id)
            try runtime.repairProfileState(persistIfChanged: true)
        }

        @discardableResult
        public func add(
            _ replacement: TextForSpeech.Replacement
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = active().adding(replacement)
            runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func add(
            _ replacement: TextForSpeech.Replacement,
            toProfileID id: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: id).adding(replacement)
            runtime.storedCustomProfilesByID[id] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func replace(
            _ replacement: TextForSpeech.Replacement
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try active().replacing(replacement)
            runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func replace(
            _ replacement: TextForSpeech.Replacement,
            inProfileID id: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: id).replacing(replacement)
            runtime.storedCustomProfilesByID[id] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func removeReplacement(
            id replacementID: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try active().removingReplacement(id: replacementID)
            runtime.storedCustomProfilesByID[runtime.activeCustomProfileID] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        @discardableResult
        public func removeReplacement(
            id replacementID: String,
            fromProfileID profileID: String
        ) throws -> TextForSpeech.Profile {
            let updatedProfile = try storedProfile(id: profileID).removingReplacement(id: replacementID)
            runtime.storedCustomProfilesByID[profileID] = updatedProfile
            try runtime.persistCurrentState()
            return updatedProfile
        }

        public func reset() throws {
            runtime.activeCustomProfileID = TextForSpeech.Profile.default.id
            runtime.storedCustomProfilesByID[TextForSpeech.Profile.default.id] = .default
            try runtime.persistCurrentState()
        }

        // MARK: Stored Profile Lookup

        private func storedProfile(id: String) throws -> TextForSpeech.Profile {
            guard let profile = runtime.storedCustomProfilesByID[id] else {
                throw TextForSpeech.RuntimeError.profileNotFound(id)
            }
            return profile
        }
    }
}
