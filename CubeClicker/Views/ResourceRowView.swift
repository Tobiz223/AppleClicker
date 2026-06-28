// CubeClicker/Views/ResourceRowView.swift
import SwiftUI

struct ResourceRowView: View {
    let symbol: String
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
            Text("\(Int(value))")
                .monospacedDigit()
                .fontWeight(.semibold)
        }
    }
}
