//
//  LabeledProgressBar.swift
//  AppGoals
//
//  Horizontal progress bar that frames the goal as a journey: the baseline at
//  the left end, the target at the right end, and a simple fill showing how far
//  along you are. Shared by the medium home-screen widget and the in-app card.
//

import SwiftUI

struct LabeledProgressBar: View {
    var progress: Double            // 0...1
    var startText: String           // baseline label (left end)
    var goalText: String            // target label (right end)
    var tint: Color = .accentColor
    var barHeight: CGFloat = 8

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.25))
                    Capsule().fill(tint).frame(width: max(barHeight, geo.size.width * clamped))
                }
            }
            .frame(height: barHeight)

            HStack(spacing: 4) {
                Text(startText)
                Spacer(minLength: 0)
                Text(goalText)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        LabeledProgressBar(progress: 0.57, startText: "$4,000", goalText: "$10,000", tint: .green, barHeight: 10)
        LabeledProgressBar(progress: 0.12, startText: "0", goalText: "500", tint: .orange, barHeight: 12)
    }
    .padding()
}
