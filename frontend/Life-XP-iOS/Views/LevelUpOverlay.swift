import SwiftUI

struct LevelUpOverlay: View {
    let level: Int
    @Binding var isShowing: Bool

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var rotation: Double = -10.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }

            VStack(spacing: 20) {
                Text("LEVEL UP!")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .orange, radius: 2, x: 2, y: 2)

                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 150, height: 150)
                        .shadow(radius: 10)

                    Text("\(level)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))

                Text("You've reached a new tier of greatness!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("HECK YES") {
                    withAnimation {
                        isShowing = false
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.blue))
                .padding(.horizontal, 40)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 20)
            )
            .padding(30)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
                rotation = 0
            }
        }
    }
}

#Preview {
    LevelUpOverlay(level: 5, isShowing: .constant(true))
}
