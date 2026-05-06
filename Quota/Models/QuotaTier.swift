import Foundation

enum QuotaFetchResult {
    case success([QuotaTier])
    case unavailable(String)   // reason, shown in UI
    case estimated([QuotaTier])
}

struct QuotaTier: Identifiable, Codable, Equatable {
    let id: String           // "five_hour", "seven_day", "rolling", "weekly"
    var utilization: Double  // fraction used (0.0–1.0)
    var resetsAt: Date?
    var isEstimated: Bool

    var remaining: Double { max(0, 1 - utilization) }

    var displayLabel: String {
        switch id {
        case "five_hour":            return "Current session"
        case "rolling":              return "滚动"
        case "seven_day", "weekly":  return "每周"
        case "monthly":              return "每月"
        case "daily":                return "Daily"
        case "pro":                  return "Pro"
        case "flash":                return "Flash"
        case "flash_lite":           return "Flash Lite"
        default:                     return id
        }
    }

    var resetsInString: String {
        guard let date = resetsAt else { return "Unknown" }
        let s = date.timeIntervalSinceNow
        guard s > 0 else { return "Resetting…" }
        let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60
        if h >= 24 { return "Resets in \(h/24)d \(h%24)h" }
        if h > 0   { return "Resets in \(h)h \(m)m" }
        return "Resets in \(m)m"
    }
}
