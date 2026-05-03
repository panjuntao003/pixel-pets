import SwiftUI

/// Renders the dog loaf icon from the design spec for the menu bar.
struct MenuBarIconRenderer: View {
    let size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let scale = sz.width / 16.0
            
            // Body
            ctx.fill(Path(CGRect(x: 3 * scale, y: 5 * scale, width: 10 * scale, height: 8 * scale)), with: .color(.primary))
            ctx.fill(Path(CGRect(x: 2 * scale, y: 6 * scale, width: 12 * scale, height: 6 * scale)), with: .color(.primary))
            
            // Ears
            ctx.fill(Path(CGRect(x: 4 * scale, y: 3 * scale, width: 2 * scale, height: 2 * scale)), with: .color(.primary))
            ctx.fill(Path(CGRect(x: 10 * scale, y: 3 * scale, width: 2 * scale, height: 2 * scale)), with: .color(.primary))
            
            // Paws
            ctx.fill(Path(CGRect(x: 4 * scale, y: 12 * scale, width: 2 * scale, height: 2 * scale)), with: .color(.primary))
            ctx.fill(Path(CGRect(x: 10 * scale, y: 12 * scale, width: 2 * scale, height: 2 * scale)), with: .color(.primary))
            
            // Face Cutout
            // We use .clear blend mode to make these transparent, 
            // so they work correctly with template images.
            ctx.blendMode = .clear
            ctx.fill(Path(CGRect(x: 5 * scale, y: 9 * scale, width: 1 * scale, height: 1 * scale)), with: .color(.white))
            ctx.fill(Path(CGRect(x: 10 * scale, y: 9 * scale, width: 1 * scale, height: 1 * scale)), with: .color(.white))
            ctx.fill(Path(CGRect(x: 7 * scale, y: 10 * scale, width: 2 * scale, height: 1 * scale)), with: .color(.white))
        }
        .frame(width: size, height: size)
    }
}
