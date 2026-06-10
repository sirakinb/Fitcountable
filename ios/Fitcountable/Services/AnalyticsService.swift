import Foundation

enum AnalyticsValue: Encodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case strings([String])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .strings(let value):
            try container.encode(value)
        }
    }
}

actor AnalyticsService {
    private let endpoint: URL
    private let anonymousId: String

    init(endpoint: URL, defaults: UserDefaults = .standard) {
        self.endpoint = endpoint
        let key = "fitcountable.analytics.anonymous_id"
        if let storedId = defaults.string(forKey: key) {
            anonymousId = storedId
        } else {
            let newId = UUID().uuidString
            defaults.set(newId, forKey: key)
            anonymousId = newId
        }
    }

    func capture(
        _ event: String,
        distinctId: String?,
        authToken: String?,
        properties: [String: AnalyticsValue] = [:]
    ) async {
        guard event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        let payload = AnalyticsPayload(
            event: event,
            distinctId: distinctId ?? anonymousId,
            properties: properties,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        do {
            request.httpBody = try JSONEncoder.fitcountable.encode(payload)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            return
        }
    }
}

private struct AnalyticsPayload: Encodable {
    var event: String
    var distinctId: String
    var properties: [String: AnalyticsValue]
    var timestamp: String

    enum CodingKeys: String, CodingKey {
        case event
        case distinctId = "distinct_id"
        case properties
        case timestamp
    }
}
