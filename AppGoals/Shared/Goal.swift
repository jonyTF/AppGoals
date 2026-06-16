//
//  Goal.swift
//  AppGoals
//
//  The user's single active goal and the math for progress + pacing.
//

import Foundation

struct Goal: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var metricID: String          // matches OverviewMetric.id, e.g. "mrr"
    var metricName: String        // display name captured at creation
    var isCurrency: Bool
    var unit: String?

    var targetValue: Double
    var startValue: Double        // metric value when the goal was created
    var startDate: Date
    var targetDate: Date

    // MARK: Progress

    /// Fraction of the way from the start value to the target (0...1).
    func progressFraction(current: Double) -> Double {
        let span = targetValue - startValue
        guard span != 0 else { return current >= targetValue ? 1 : 0 }
        return clamp((current - startValue) / span)
    }

    /// Whether the goal has been reached.
    func isComplete(current: Double) -> Bool {
        targetValue >= startValue ? current >= targetValue : current <= targetValue
    }

    // MARK: Pacing

    /// Where the metric "should" be right now assuming a straight line from
    /// start to target across the full time window.
    func expectedValueNow(asOf now: Date) -> Double {
        let totalInterval = targetDate.timeIntervalSince(startDate)
        guard totalInterval > 0 else { return targetValue }
        let elapsed = clamp(now.timeIntervalSince(startDate) / totalInterval)
        return startValue + (targetValue - startValue) * elapsed
    }

    enum PaceStatus: String {
        case ahead, onTrack, behind, complete

        var label: String {
            switch self {
            case .ahead: return "Ahead of pace"
            case .onTrack: return "On track"
            case .behind: return "Behind pace"
            case .complete: return "Goal reached 🎉"
            }
        }
    }

    func paceStatus(current: Double, asOf now: Date) -> PaceStatus {
        if isComplete(current: current) { return .complete }
        let expected = expectedValueNow(asOf: now)
        // Normalize for goals that go up vs (rarely) down.
        let rising = targetValue >= startValue
        let delta = rising ? (current - expected) : (expected - current)
        let scale = max(abs(targetValue - startValue), 1)
        let ratio = delta / scale
        if ratio > 0.02 { return .ahead }
        if ratio < -0.02 { return .behind }
        return .onTrack
    }

    var daysRemaining: Int {
        let secs = targetDate.timeIntervalSinceNow
        return max(0, Int(ceil(secs / 86_400)))
    }

    func remaining(current: Double) -> Double {
        max(0, targetValue - current)
    }

    var formattedTarget: String {
        OverviewMetric.format(value: targetValue, isCurrency: isCurrency, unit: unit)
    }

    private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}
