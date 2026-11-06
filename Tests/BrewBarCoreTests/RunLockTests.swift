import BrewBarCore
import Testing

struct RunLockTests {
    @Test func tryAcquireFailsWhileLocked() async {
        let lock = RunLock()
        #expect(await lock.tryAcquire())
        #expect(await !lock.tryAcquire())
        await lock.release()
        #expect(await lock.tryAcquire())
    }

    @Test func acquireWaitsForRelease() async {
        let lock = RunLock()
        await lock.acquire()
        let order = Order()
        let waiter = Task {
            await lock.acquire()
            await order.add("second")
            await lock.release()
        }
        try? await Task.sleep(for: .milliseconds(50))
        await order.add("first")
        await lock.release()
        await waiter.value
        #expect(await order.items == ["first", "second"])
    }

    @Test func handsTheLockToTheWaiter() async {
        let lock = RunLock()
        await lock.acquire()
        let waiter = Task { await lock.acquire() }
        try? await Task.sleep(for: .milliseconds(50))
        await lock.release()
        await waiter.value
        #expect(await !lock.tryAcquire())
    }
}

private actor Order {
    private(set) var items: [String] = []
    func add(_ item: String) { items.append(item) }
}
