import Foundation

/// Main-queue sampling state for one central manager's current scan.
final class AdvertisementSampler {
    let divisor: Int
    private var counts: [UUID: Int] = [:]

    init(divisor: Int = 1) {
        self.divisor = divisor
    }

    func accepts(identifier: UUID) -> Bool {
        if divisor == 1 { return true }
        let count = counts[identifier] ?? 0
        counts[identifier] = count == divisor - 1 ? 0 : count + 1
        return count == 0
    }
}
