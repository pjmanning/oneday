import Foundation

/// A single OneDay clip in the vertical feed.
///
/// Rules encoded in the model: one headline, duration between 1 and 3 minutes,
/// no external link fields, optional AI summary placeholder.
struct FeedPost: Identifiable, Decodable, Hashable, Sendable {
    let id: String
    let headline: String
    let durationSeconds: Int
    let dayKey: String
    let authorSubject: String
    let authorDisplayName: String
    let aiSummary: String?
    let createdAt: Date

    var durationLabel: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case headline
        case durationSeconds
        case dayKey
        case authorSubject
        case authorDisplayName
        case aiSummary
        case creationTime = "_creationTime"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        headline = try container.decode(String.self, forKey: .headline)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        authorSubject = try container.decode(String.self, forKey: .authorSubject)
        authorDisplayName = try container.decode(String.self, forKey: .authorDisplayName)
        aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
        let milliseconds = try container.decode(Double.self, forKey: .creationTime)
        createdAt = Date(timeIntervalSince1970: milliseconds / 1000)
    }

    init(
        id: String,
        headline: String,
        durationSeconds: Int,
        dayKey: String,
        authorSubject: String,
        authorDisplayName: String,
        aiSummary: String?,
        createdAt: Date
    ) {
        self.id = id
        self.headline = headline
        self.durationSeconds = durationSeconds
        self.dayKey = dayKey
        self.authorSubject = authorSubject
        self.authorDisplayName = authorDisplayName
        self.aiSummary = aiSummary
        self.createdAt = createdAt
    }
}
