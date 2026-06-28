// CubeClicker/Views/ShopItemView.swift
import SwiftUI

struct ShopItemView: View {
    let type: BuildingType
    @EnvironmentObject var viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text(type.symbol)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(type.displayName).fontWeight(.semibold)
                    if viewModel.buildingCount(type) > 0 {
                        Text("×\(viewModel.buildingCount(type))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(type.outputDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(type.costText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Group {
                if !viewModel.isUnlocked(type) {
                    Text("🔒")
                        .font(.title3)
                } else {
                    Button("Купить") {
                        viewModel.purchase(type)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .disabled(!viewModel.canPurchase(type))
                }
            }
        }
        .padding(10)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
