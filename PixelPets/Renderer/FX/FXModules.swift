import SwiftUI

struct TypingSparksFX: View {
    let frame: Int
    let intensity: Double
    
    var body: some View {
        Canvas { ctx, size in
            let count = Int(5 * intensity)
            for i in 0..<count {
                let seed = Double(frame + i * 100)
                let x = size.width * (0.5 + 0.3 * sin(seed * 0.1))
                let y = size.height * (0.5 + 0.2 * cos(seed * 0.15))
                
                let sparkSize: CGFloat = 2.0
                ctx.fill(Path(CGRect(x: x, y: y, width: sparkSize, height: sparkSize)), with: .color(.cyan.opacity(0.8)))
            }
        }
    }
}

struct AlertPulseFX: View {
    let frame: Int
    let intensity: Double
    
    var body: some View {
        let alpha = (0.1 + 0.2 * sin(Double(frame) * 0.1)) * intensity
        Color.red.opacity(alpha)
            .edgesIgnoringSafeArea(.all)
    }
}

struct EnergyFlowFX: View {
    let frame: Int
    let intensity: Double
    
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 20.0
            let offset = CGFloat(frame % 20)
            
            for x in stride(from: -step, to: size.width + step, by: step) {
                let lineX = x + offset
                let path = Path { p in
                    p.move(to: CGPoint(x: lineX, y: size.height * 0.7))
                    p.addLine(to: CGPoint(x: lineX - 10, y: size.height))
                }
                ctx.stroke(path, with: .color(.green.opacity(0.3 * intensity)), lineWidth: 2)
            }
        }
    }
}
