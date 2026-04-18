import Foundation

// MARK: - Runtime Normalization

public extension TextForSpeech.Runtime {
    struct Normalization {
        let runtime: TextForSpeech.Runtime

        init(runtime: TextForSpeech.Runtime) {
            self.runtime = runtime
        }
    }
}
