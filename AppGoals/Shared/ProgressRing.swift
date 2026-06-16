//
//  ProgressRing.swift
//  AppGoals
//
//  Reusable circular progress ring shared by the dashboard and the widgets.
//

import SwiftUI

struct ProgressRing: View {
    var progress: Double          // 0...1
    var lineWidth: CGFloat = 10
    var tint: Color = .accentColor
    var showsPercent: Bool = true

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if showsPercent {
                Text(clamped, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
            }
        }
        .animation(.snappy, value: clamped)
    }
}

#Preview {
    HStack(spacing: 20) {
        ProgressRing(progress: 0.32).frame(width: 90, height: 90)
        ProgressRing(progress: 0.78, tint: .green).frame(width: 90, height: 90)
        ProgressRing(progress: 1.0, tint: .green).frame(width: 90, height: 90)
    }
    .padding()
}
