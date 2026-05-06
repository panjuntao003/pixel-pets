import SwiftUI

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        self.init(red: Double((n>>16)&0xFF)/255,
                  green: Double((n>>8)&0xFF)/255,
                  blue: Double(n&0xFF)/255)
    }
}

enum AgentPalette {
    static let claudeBody = Color(hex: "D4884A")
    static let claudeLight = Color(hex: "E8A870")
    static let claudeShadow = Color(hex: "A06030")

    static let geminiBody = Color(hex: "4A7ABF")
    static let geminiLight = Color(hex: "6A9ADF")
    static let geminiShadow = Color(hex: "2A5A9F")

    static let codexBody = Color(hex: "C8C8D8")
    static let codexLight = Color(hex: "E8E8F0")
    static let codexShadow = Color(hex: "A8A8C0")

    static let antenna = Color(hex: "5DADE2")

    static let quotaGreen = Color(hex: "34C759")
    static let quotaOrange = Color(hex: "FF9500")
    static let quotaRed = Color(hex: "FF3B30")
    static let quotaTrack = Color(hex: "E5E5EA")

    static let claude = Color(hex: "D4884A")
    static let codexTop = Color(hex: "C8C8D8")
    static let codexBottom = Color(hex: "A8A8C0")
    static let outline = Color(hex: "000000")
    static let screen = Color.white
    static let quotaYellow = Color(hex: "FF9500")

    static func bodyColor(for skin: AgentSkin) -> Color {
        switch skin {
        case .claude: return claudeBody
        case .gemini: return geminiBody
        case .codex: return codexBody
        }
    }

    static func lightColor(for skin: AgentSkin) -> Color {
        switch skin {
        case .claude: return claudeLight
        case .gemini: return geminiLight
        case .codex: return codexLight
        }
    }

    static func shadowColor(for skin: AgentSkin) -> Color {
        switch skin {
        case .claude: return claudeShadow
        case .gemini: return geminiShadow
        case .codex: return codexShadow
        }
    }
}
