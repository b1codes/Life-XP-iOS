import SwiftUI

struct LLCGlassModifier: ViewModifier {
    var borderRadius: CGFloat = 16.0
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: borderRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .background(
                Color.white.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: borderRadius))
    }
}

struct LLCThermalGlow: ViewModifier {
    @State private var glowOpacity: Double = 0.0
    @State private var glowScale: CGFloat = 0.5
    @State private var contactPoint: CGPoint = .zero
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.4), Color.clear]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity)
                    .position(contactPoint)
                    .allowsHitTesting(false)
                }
            )
            .gesture(
                SpatialTapGesture().onEnded { value in
                    triggerGlow(at: value.location)
                }
            )
    }
    
    private func triggerGlow(at point: CGPoint) {
        contactPoint = point
        
        withAnimation(.easeOut(duration: 0.05)) {
            glowOpacity = 1.0
            glowScale = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.interpolatingSpring(stiffness: 180, damping: 12)) {
                glowScale = 1.5
            }
            withAnimation(.easeOut(duration: 0.3)) {
                glowOpacity = 0.0
            }
        }
    }
}

extension View {
    func llcGlass(borderRadius: CGFloat = 16.0) -> some View {
        self.modifier(LLCGlassModifier(borderRadius: borderRadius))
    }
    
    func llcThermalGlow() -> some View {
        self.modifier(LLCThermalGlow())
    }
}
