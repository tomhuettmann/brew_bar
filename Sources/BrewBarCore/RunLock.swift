/// Lets only one Homebrew command run at a time.
public actor RunLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Takes the lock if it is free. Returns whether it was taken.
    public func tryAcquire() -> Bool {
        guard !isLocked else { return false }
        isLocked = true
        return true
    }

    /// Waits until the lock is free and takes it.
    public func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    public func release() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
