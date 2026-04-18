import Foundation

public extension TextForSpeech.Runtime {
    struct Persistence {
        let runtime: TextForSpeech.Runtime

        init(runtime: TextForSpeech.Runtime) {
            self.runtime = runtime
        }
    }
}
