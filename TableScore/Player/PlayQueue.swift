import Foundation

/// Pure queue logic for the player: ordering, shuffle, and repeat.
/// Deliberately free of AVFoundation so it can be unit-tested.
struct PlayQueue<Element> {
    /// Items in original (catalog) order.
    private(set) var items: [Element]
    /// Permutation of `items.indices` defining play order.
    private(set) var playOrder: [Int]
    /// Index into `playOrder`; nil only when the queue is empty.
    private(set) var position: Int?
    private(set) var isShuffled = false
    var repeatMode: RepeatMode

    init(items: [Element], startAt originalIndex: Int = 0, repeatMode: RepeatMode = .all) {
        self.items = items
        self.playOrder = Array(items.indices)
        self.repeatMode = repeatMode
        self.position = items.isEmpty ? nil : min(max(0, originalIndex), items.count - 1)
    }

    var isEmpty: Bool { items.isEmpty }

    var current: Element? {
        position.map { items[playOrder[$0]] }
    }

    var currentOriginalIndex: Int? {
        position.map { playOrder[$0] }
    }

    /// Everything after the current item in play order; when repeating all,
    /// wraps around (excluding the current item itself).
    var upNext: [Element] {
        guard let position else { return [] }
        let after = playOrder[(position + 1)...].map { items[$0] }
        guard repeatMode == .all else { return Array(after) }
        let before = playOrder[..<position].map { items[$0] }
        return after + before
    }

    /// Advance to the next item. Auto-advance (track finished) honors
    /// repeat-one by staying put; a user tap always moves on. Returns nil
    /// when playback should stop (repeat off, end of queue).
    mutating func advance(userInitiated: Bool) -> Element? {
        guard let pos = position else { return nil }
        if !userInitiated && repeatMode == .one { return current }
        if pos + 1 < playOrder.count {
            position = pos + 1
            return current
        }
        if repeatMode != .off {
            position = 0
            return current
        }
        return nil
    }

    /// Step back one item, wrapping when repeating all. (Restart-if-mid-track
    /// behavior lives in the player, which knows elapsed time.)
    mutating func goBack() -> Element? {
        guard let pos = position else { return nil }
        if pos > 0 {
            position = pos - 1
        } else if repeatMode == .all {
            position = playOrder.count - 1
        }
        return current
    }

    @discardableResult
    mutating func jump(toOriginalIndex index: Int) -> Element? {
        guard items.indices.contains(index),
              let newPosition = playOrder.firstIndex(of: index) else { return nil }
        position = newPosition
        return current
    }

    /// Toggling shuffle keeps the current item playing: it becomes the head
    /// of the shuffled order; unshuffling returns to catalog order at the
    /// current item's original slot.
    mutating func setShuffled<G: RandomNumberGenerator>(_ shuffled: Bool, using generator: inout G) {
        guard shuffled != isShuffled else { return }
        isShuffled = shuffled
        guard let currentIndex = currentOriginalIndex else { return }
        if shuffled {
            var rest = items.indices.filter { $0 != currentIndex }
            rest.shuffle(using: &generator)
            playOrder = [currentIndex] + rest
            position = 0
        } else {
            playOrder = Array(items.indices)
            position = currentIndex
        }
    }

    mutating func setShuffled(_ shuffled: Bool) {
        var generator = SystemRandomNumberGenerator()
        setShuffled(shuffled, using: &generator)
    }
}
