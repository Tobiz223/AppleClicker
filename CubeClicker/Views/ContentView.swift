// CubeClicker/Views/ContentView.swift
import SwiftUI
import SpriteKit

struct ContentView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var worldScene = WorldScene()

    var body: some View {
        HStack(spacing: 0) {
            LeftPanelView()
                .frame(width: 300)
                .background(Color(.windowBackgroundColor))

            Divider()

            SpriteView(scene: worldScene)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 820, minHeight: 520)
        .onAppear {
            worldScene.scaleMode = .resizeFill
            worldScene.gameViewModel = viewModel
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 20) {
                    ResourceRowView(symbol: "🪵", value: viewModel.state.wood)
                    ResourceRowView(symbol: "🪨", value: viewModel.state.stone)
                    ResourceRowView(symbol: "⚙️", value: viewModel.state.metal)
                }
                .font(.headline)
            }
        }
    }
}
