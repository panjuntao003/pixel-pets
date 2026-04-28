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
    static let claude      = Color(hex: "D97757")
    static let codexTop    = Color(hex: "7851FB")
    static let codexBottom = Color(hex: "2853FF")
    static let opencode    = Color(hex: "000000")
    static let outline     = Color(hex: "000000")
    static let screen      = Color.white
    static let quotaGreen  = Color(hex: "34A853")
    static let quotaYellow = Color(hex: "FBBC05")
    static let quotaRed    = Color(hex: "EA4335")
}
