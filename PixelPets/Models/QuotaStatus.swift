import Foundation

enum QuotaStatus: String, Codable, CaseIterable {
    case normal
    case low
    case exhausted
    case unavailable
    case unknown
}
