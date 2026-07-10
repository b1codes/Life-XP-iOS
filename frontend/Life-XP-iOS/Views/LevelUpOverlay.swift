import SwiftUI

struct LevelUpOverlay: View {
    let level: Int
    @Binding var isShowing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                Text("LEVEL UP")
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.primary)
                    .shadow(color: .llcThermalCorona.opacity(0.5), radius: 12)

                ZStack {
                    ThermalBurstView(diameter: 220)

                    Circle()
                        .fill(Color.llcGlassFill)
                        .overlay(
                            Circle().stroke(Color.llcGlassBorder, lineWidth: 0.5)
                        )
                        .frame(width: 150, height: 150)

                    Text("\(level)")
                        .font(.system(size: 72, weight: .black))
                        .kerning(-1)
                        .foregroundStyle(.primary)
                }
                .scaleEffect(scale)

                Text("Your stats have been recalibrated.")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: dismiss) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .background(Color.llcGlassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.llcGlassBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .llcThermalGlow(diameter: 110)
                .padding(.horizontal, 40)
            }
            .padding()
            .llcGlass(borderRadius: 25)
            .padding(30)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = 1.0
                    opacity = 1.0
                }
                return
            }

            withAnimation(.interpolatingSpring(stiffness: 180, damping: 12)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    private func dismiss() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation {
            isShowing = false
        }
    }
}

#Preview {
    LevelUpOverlay(level: 5, isShowing: .constant(true))
}
