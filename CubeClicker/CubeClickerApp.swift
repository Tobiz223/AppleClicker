import SwiftUI

@main
struct CubeClickerApp: App {
    @StateObject private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onDisappear { viewModel.save() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 950, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
