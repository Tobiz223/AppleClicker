// CubeClicker/Views/LeftPanelView.swift
import SwiftUI

struct LeftPanelView: View {
    @EnvironmentObject var viewModel: GameViewModel
    @State private var isClicking = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.click()
                withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) {
                    isClicking = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.08, dampingFraction: 0.4)) {
                        isClicking = false
                    }
                }
            } label: {
                CubeView(tier: viewModel.cubeTier)
                    .frame(width: 110, height: 110)
                    .scaleEffect(isClicking ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .padding(.top, 28)

            Text("+\(Int(viewModel.clickOutput)) 🪵 за клик")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Divider().padding(.vertical, 14)

            Text("МАГАЗИН")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(BuildingType.allCases, id: \.self) { type in
                        ShopItemView(type: type)
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - CubeView

private struct CubeView: View {
    let tier: Int

    private var faceColor: Color {
        switch tier {
        case 0: return Color(red: 0.60, green: 0.38, blue: 0.18)  // Wood
        case 1: return Color(red: 0.58, green: 0.58, blue: 0.58)  // Stone
        case 2: return Color(red: 0.35, green: 0.40, blue: 0.65)  // Metal
        default: return Color(red: 0.85, green: 0.70, blue: 0.10) // Gold
        }
    }

    var body: some View {
        ZStack {
            // Bottom face (shadow)
            RoundedRectangle(cornerRadius: 10)
                .fill(faceColor.opacity(0.5))
                .frame(width: 100, height: 100)
                .offset(y: 6)

            // Main face
            RoundedRectangle(cornerRadius: 10)
                .fill(faceColor)
                .frame(width: 100, height: 100)

            // Top highlight
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.18))
                .frame(width: 80, height: 35)
                .offset(y: -22)

            // Pixel grid lines
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 100, y: 0))
            }
            .stroke(Color.black.opacity(0.08), lineWidth: 1)
            .frame(width: 100, height: 100)
        }
    }
}
