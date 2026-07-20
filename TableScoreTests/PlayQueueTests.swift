import XCTest
@testable import TableScore

/// Deterministic RNG so shuffle assertions are stable.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class PlayQueueTests: XCTestCase {
    private func makeQueue(
        count: Int = 5,
        startAt: Int = 0,
        repeatMode: RepeatMode = .all
    ) -> PlayQueue<String> {
        PlayQueue(items: (0..<count).map { "t\($0)" }, startAt: startAt, repeatMode: repeatMode)
    }

    // MARK: Advancing

    func testAdvanceWalksQueueInOrder() {
        var queue = makeQueue()
        XCTAssertEqual(queue.current, "t0")
        XCTAssertEqual(queue.advance(userInitiated: true), "t1")
        XCTAssertEqual(queue.advance(userInitiated: false), "t2")
    }

    func testRepeatAllWrapsAtEnd() {
        var queue = makeQueue(count: 3, startAt: 2, repeatMode: .all)
        XCTAssertEqual(queue.advance(userInitiated: false), "t0")
    }

    func testRepeatOffStopsAtEnd() {
        var queue = makeQueue(count: 3, startAt: 2, repeatMode: .off)
        XCTAssertNil(queue.advance(userInitiated: false))
        XCTAssertNil(queue.advance(userInitiated: true))
        // Queue stays on the last track so the UI still shows it.
        XCTAssertEqual(queue.current, "t2")
    }

    func testRepeatOneRepeatsOnAutoAdvanceButUserSkips() {
        var queue = makeQueue(count: 3, startAt: 1, repeatMode: .one)
        XCTAssertEqual(queue.advance(userInitiated: false), "t1")
        XCTAssertEqual(queue.advance(userInitiated: false), "t1")
        XCTAssertEqual(queue.advance(userInitiated: true), "t2")
    }

    // MARK: Going back

    func testGoBackSteps() {
        var queue = makeQueue(startAt: 2)
        XCTAssertEqual(queue.goBack(), "t1")
        XCTAssertEqual(queue.goBack(), "t0")
    }

    func testGoBackAtStartWrapsWhenRepeatingAll() {
        var queue = makeQueue(count: 4, startAt: 0, repeatMode: .all)
        XCTAssertEqual(queue.goBack(), "t3")
    }

    func testGoBackAtStartStaysWhenRepeatOff() {
        var queue = makeQueue(count: 4, startAt: 0, repeatMode: .off)
        XCTAssertEqual(queue.goBack(), "t0")
    }

    // MARK: Shuffle

    func testShuffleKeepsCurrentTrackFirstAndIsAPermutation() {
        var queue = makeQueue(count: 10, startAt: 4)
        var generator = SeededGenerator(state: 42)
        queue.setShuffled(true, using: &generator)

        XCTAssertEqual(queue.current, "t4")
        XCTAssertEqual(queue.playOrder.first, 4)
        XCTAssertEqual(Set(queue.playOrder), Set(0..<10))
        XCTAssertNotEqual(queue.playOrder, Array(0..<10), "seeded shuffle should not be identity")
    }

    func testUnshuffleRestoresCatalogOrderAtCurrentTrack() {
        var queue = makeQueue(count: 10, startAt: 4)
        var generator = SeededGenerator(state: 7)
        queue.setShuffled(true, using: &generator)
        _ = queue.advance(userInitiated: true)
        let playingBefore = queue.current

        queue.setShuffled(false, using: &generator)

        XCTAssertEqual(queue.current, playingBefore)
        XCTAssertEqual(queue.playOrder, Array(0..<10))
    }

    // MARK: Up next

    func testUpNextWrapsWhenRepeatingAll() {
        var queue = makeQueue(count: 4, startAt: 2, repeatMode: .all)
        XCTAssertEqual(queue.upNext, ["t3", "t0", "t1"])
        queue.repeatMode = .off
        XCTAssertEqual(queue.upNext, ["t3"])
    }

    // MARK: Jump

    func testJumpSelectsTrackByOriginalIndex() {
        var queue = makeQueue(count: 5)
        XCTAssertEqual(queue.jump(toOriginalIndex: 3), "t3")
        XCTAssertEqual(queue.advance(userInitiated: true), "t4")
    }

    func testEmptyQueueIsInert() {
        var queue = PlayQueue<String>(items: [])
        XCTAssertNil(queue.current)
        XCTAssertNil(queue.advance(userInitiated: true))
        XCTAssertNil(queue.goBack())
        XCTAssertEqual(queue.upNext, [])
    }
}
