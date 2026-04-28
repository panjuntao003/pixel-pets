import SwiftUI

struct PetDisplayView: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        VStack(spacing: 6) {
            AnimationClock(fps: 30) { frame in
                BitBotRenderer(viewModel: viewModel, size: 22, frame: frame)
                    .scaleEffect(3).frame(width: 66, height: 66)
            }
            Text(viewModel.activeSkin.personalityTag)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary).tracking(1)
            if !viewModel.hooksAvailable {
                Text("实时 Hook 不可用 · 未检测到 Node.js")
                    .font(.system(size: 9)).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 110)
    }
}
