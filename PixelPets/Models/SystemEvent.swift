import Foundation

enum SystemEvent: String, Codable {
    case appIdle
    case userStartedRequest
    case aiThinking
    case aiStreaming
    case requestSucceeded
    case requestFailed
    case quotaLow
    case quotaResetting
    case quotaRecovered
}
