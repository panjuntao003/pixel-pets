import Foundation

enum QuotaSource: String, Codable {
    case providerAPI
    case localCLI
    case estimated
    case manual
    case unknown
}
