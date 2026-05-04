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
                }
                HStack {
                    Text("EVENT:").bold()
                    Text("\(coordinator.currentEvent.rawValue.uppercased())")
                        .foregroundColor(.yellow)
                }
                HStack {
                    Text("VISUAL:").bold()
                    Text("P:\(viewModel.visualState.petState.rawValue) S:\(viewModel.visualState.sceneState.rawValue)")
                }
                HStack {
                    Text("INTENSITY:").bold()
                    Text(String(format: "%.2f", viewModel.visualState.intensity))
                }
            }
            .font(.system(size: 9, design: .monospaced))
            
            Divider().background(Color.white.opacity(0.2))
            
            Text("EVENT TIMELINE (LATEST 5)")
                .font(.system(size: 8)).bold()
                .opacity(0.6)
            
            ForEach(coordinator.eventHistory.prefix(5), id: \.id) { record in
                HStack {
                    Text(record.timestamp, style: .time)
                    Text("[\(record.provider.rawValue)]")
                    Text(record.event.rawValue)
                }
                .font(.system(size: 8, design: .monospaced))
                .opacity(0.8)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
        .foregroundColor(.white)
    }
}
