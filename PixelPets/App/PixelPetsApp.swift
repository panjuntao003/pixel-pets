import SwiftUI

@main
struct PixelPetsApp: App {
    @StateObject private var viewModel = PetViewModel.mock()

    var body: some Scene {
        WindowGroup {
            PopoverView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}
