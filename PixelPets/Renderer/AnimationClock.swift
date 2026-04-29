import SwiftUI

struct AnimationClock<Content: View>: View {
    let fps: Double
    @ViewBuilder let content: (Int) -> Content
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / fps)) { ctx in
            content(Self.frameIndex(since: startDate, at: ctx.date, fps: fps))
        }
    }

    static func frameIndex(since startDate: Date, at date: Date, fps: Double) -> Int {
        max(0, Int(date.timeIntervalSince(startDate) * fps))
    }
}
