import SwiftUI

extension Color {
    /// Thermal Heat spectrum origin (`.claude/context/llc-standards/branding.md`).
    static let llcThermalCore = Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
    static let llcThermalCorona = Color(red: 1.0, green: 0.584, blue: 0.0) // #FF9500
    static let llcGlassFill = Color.white.opacity(0.05)
    static let llcGlassBorder = Color.white.opacity(0.2)

    /// RPG stat identity colors (Dashboard character sheet). Not part of the
    /// Thermal Heat system — a separate, static category vocabulary, so they
    /// stay outside the Earned Color Rule.
    static let llcStatStrength = Color.red
    static let llcStatIntelligence = Color.purple
    static let llcStatVitality = Color.green
    static let llcStatCharisma = Color.yellow
}

struct LLCGlassModifier: ViewModifier {
    var borderRadius: CGFloat = 16.0

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: borderRadius)
                    .stroke(Color.llcGlassBorder, lineWidth: 0.5)
            )
            .background(
                Color.llcGlassFill
            )
            .clipShape(RoundedRectangle(cornerRadius: borderRadius))
    }
}

struct LLCThermalGlow: ViewModifier {
    var diameter: CGFloat = 200
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowOpacity: Double = 0.0
    @State private var glowScale: CGFloat = 0.5
    @State private var contactPoint: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .overlay(
                ThermalGradient(diameter: diameter)
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity)
                    .position(contactPoint)
                    .allowsHitTesting(false)
            )
            // simultaneousGesture, not gesture: lets this compose with an
            // enclosing Button's own tap recognition instead of stealing it.
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    triggerGlow(at: value.location)
                }
            )
    }

    private func triggerGlow(at point: CGPoint) {
        contactPoint = point

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.15)) {
                glowOpacity = 1.0
                glowScale = 1.2
            }
            withAnimation(.easeInOut(duration: 0.15).delay(0.15)) {
                glowOpacity = 0.0
            }
            return
        }

        // Phase 1: Excitation (50ms) — .claude/context/llc-standards/interaction-physics.md
        withAnimation(.easeOut(duration: 0.05)) {
            glowOpacity = 1.0
            glowScale = 1.2
        }

        // Phase 2: Dissipation (300ms), spring stiffness 180 / damping 12
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

/// The Thermal Heat radial gradient, shared by tap-triggered (`LLCThermalGlow`)
/// and auto-triggered (`ThermalBurstView`) glow events.
///
/// `.plusLighter` is additive: it only reads as Thermal Core/Corona over a
/// dark surface. Since the app follows system appearance rather than forcing
/// dark mode, the gradient carries its own soft dark backing so the glow
/// stays on-spec in light mode too, instead of washing out to pale cream.
struct ThermalGradient: View {
    var diameter: CGFloat = 200

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                center: .center,
                startRadius: 0,
                endRadius: diameter / 2
            )
            .frame(width: diameter, height: diameter)

            RadialGradient(
                gradient: Gradient(colors: [.llcThermalCore, .llcThermalCorona, .clear]),
                center: .center,
                startRadius: 0,
                endRadius: diameter / 2
            )
            .frame(width: diameter, height: diameter)
            .blendMode(.plusLighter)
        }
    }
}

/// A Thermal Glow that fires once on appear instead of on tap — for moments
/// the system itself initiates (level up, milestone reached) rather than
/// ones the user taps into.
struct ThermalBurstView: View {
    var diameter: CGFloat = 220
    var restingOpacity: Double = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.5

    var body: some View {
        ThermalGradient(diameter: diameter)
            .scaleEffect(scale)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear(perform: trigger)
    }

    private func trigger() {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) {
                opacity = restingOpacity
                scale = 1.0
            }
            return
        }

        withAnimation(.easeOut(duration: 0.05)) {
            opacity = 1.0
            scale = 1.2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.interpolatingSpring(stiffness: 180, damping: 12)) {
                scale = 1.5
            }
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = restingOpacity
            }
        }
    }
}

extension View {
    func llcGlass(borderRadius: CGFloat = 16.0) -> some View {
        self.modifier(LLCGlassModifier(borderRadius: borderRadius))
    }

    func llcThermalGlow(diameter: CGFloat = 200) -> some View {
        self.modifier(LLCThermalGlow(diameter: diameter))
    }
}
