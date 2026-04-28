final class GrowthEngine {
    private let levelThresholds: [(tokens: Int, level: Int)] = [
        (20_000_000, 4),
        (5_000_000, 3),
        (1_000_000, 2)
    ]

    private let accessoryThresholds: [(tokens: Int, accessory: Accessory)] = [
        (500_000, .sprout),
        (2_000_000, .battery),
        (3_000_000, .headset),
        (5_000_000, .minidrone),
        (8_000_000, .jetpack),
        (10_000_000, .halo),
        (12_000_000, .codecloud),
        (15_000_000, .cape),
        (20_000_000, .antenna)
    ]

    func compute(totalTokens: Int) -> (level: Int, accessories: [Accessory]) {
        let level = levelThresholds.first { totalTokens >= $0.tokens }?.level ?? 1
        let accessories = accessoryThresholds
            .filter { totalTokens >= $0.tokens }
            .map(\.accessory)

        return (level, accessories)
    }

    func newMilestones(from oldTotalTokens: Int, to newTotalTokens: Int) -> [Accessory] {
        accessoryThresholds
            .filter { $0.tokens > oldTotalTokens && $0.tokens <= newTotalTokens }
            .map(\.accessory)
    }
}
