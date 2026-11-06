public enum BrewError: Error, Equatable, Sendable {
    case brewNotFound
    case timeout
    /// Another Homebrew process holds the lock, e.g. an upgrade in a terminal.
    case busy
    case failed(String)
    case unexpectedOutput

    public var message: String {
        switch self {
        case .brewNotFound: "Homebrew Not Found"
        case .timeout: "Homebrew Took Too Long"
        case .busy: "Homebrew Is Busy"
        case .failed(let detail): detail.isEmpty ? "Homebrew Failed" : "Homebrew Failed: \(detail)"
        case .unexpectedOutput: "Unexpected Homebrew Output"
        }
    }
}
