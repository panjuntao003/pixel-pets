import SwiftUI

struct AnimationClock<Content: View>: View {
    let fps: Double
    @ViewBuilder let content: (Int) -> Content
    @State private var frame = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / fps)) { ctx in
            content(frame)
                .onChange(of: ctx.date) { _, _ in frame += 1 }
        }
    }
}
