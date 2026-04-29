import SwiftUI

protocol FaceProvider {
    func draw(in ctx: GraphicsContext, state: PetState, frame: Int, scale: CGFloat)
}

extension GraphicsContext {
    func fillPixel(x: Int, y: Int, color: Color, scale: CGFloat) {
        fill(Path(CGRect(x: CGFloat(x)*scale, y: CGFloat(y)*scale,
                         width: scale, height: scale)),
             with: .color(color))
    }
}
