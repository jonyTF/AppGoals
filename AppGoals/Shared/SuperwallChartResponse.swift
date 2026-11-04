import Foundation

struct SuperwallChartResponse: Decodable {
    struct Axis: Decodable {
        let key: String
    }

    struct Point: Decodable {
        struct Value: Decodable {
            let y: Double
            let extra: [String: Double]
        }
        let x: String
        let values: [String: Value]
    }

    let data: [Point]
    let yAxis: Axis

    enum CodingKeys: String, CodingKey {
        case data
        case yAxis = "y_axis"
    }

    func latestValue(metric: String, extra: String? = nil) throws -> Double {
        guard let point = data.max(by: { $0.x < $1.x }) else { return 0 }
        return try value(in: point, metric: metric, extra: extra)
    }

    func total(metric: String) throws -> Double {
        try data.reduce(0) { try $0 + value(in: $1, metric: metric) }
    }

    private func value(in point: Point, metric: String, extra: String? = nil) throws -> Double {
        guard let value = point.values[metric] else { throw SuperwallError.decoding }
        let number: Double?
        if let extra {
            number = value.extra[extra]
        } else {
            number = value.y
        }
        guard let number, number.isFinite else {
            throw SuperwallError.decoding
        }
        return number
    }
}
