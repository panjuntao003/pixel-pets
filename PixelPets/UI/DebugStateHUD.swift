import SwiftUI

struct DebugStateHUD: View {
    @ObservedObject var viewModel: PetViewModel
    @StateObject private var coordinator = ActivityCoordinator.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                HStack {
                    Text("PROVIDER:").bold()
                    Text("\(coordinator.activeProvider.rawValue.uppercased())")
                        .foregroundColor(.cyan)
                    if coordinator.priorityOverrideActive {
                        Text("[OVERRIDE]").foregroundColor(.orange).font(.system(size: 7))
                    }
                }
                HStack {
                    Text("EVENT:").bold()
                    Text("\(coordinator.currentEvent.rawValue.uppercased())")
                        .foregroundColor(.yellow)
                    if coordinator.isWaitingForMinDuration {
                        Text("[MIN_DUR]").foregroundColor(.green).font(.system(size: 7))
                    }
                }
                HStack {
                    Text("VISUAL:").bold()
                    Text("P:\(viewModel.visualState.petState.rawValue) S:\(viewModel.visualState.sceneState.rawValue)")
                }
            }
            .font(.system(size: 9, design: .monospaced))
            
            Divider().background(Color.white.opacity(0.2))
            
            Text("EVENT TIMELINE")
                .font(.system(size: 8)).bold()
                .opacity(0.6)
            
            ForEach(coordinator.eventHistory.prefix(5), id: \.id) { record in
                Text("[\(record.provider.rawValue)] \(record.event.rawValue)")
                    .font(.system(size: 8, design: .monospaced))
                    .opacity(0.8)
            }
            
            Button("COPY DIAGNOSTICS") {
                let summary = coordinator.diagnosticsSummary()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(summary, forType: .string)
            }
            .buttonStyle(.plain)
            .font(.system(size: 8))
            .padding(.top, 2)
            .foregroundColor(.cyan)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
        .foregroundColor(.white)
    }
}
