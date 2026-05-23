//
//  LockInRewardOverlay.swift
//  Life-XP-iOS
//
//  Created by Gemini CLI on 1/20/26.
//

import SwiftUI

struct LockInRewardOverlay: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var isAnimating = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background blur/dim
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.5)) {
                        isAnimating = true
                    }
                }

            if showContent {
                VStack(spacing: 30) {
                    Text("CHALLENGE COMPLETE!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange, radius: 2)
                        .multilineTextAlignment(.center)
                        .transition(.scale.combined(with: .opacity))

                    // Trophy Icon with Glow
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 150, height: 150)
                            .blur(radius: 20)
                            .scaleEffect(isAnimating ? 1.2 : 0.8)

                        Image(systemName: "lock.shield.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.yellow)
                            .shadow(color: .orange, radius: 10)
                            .scaleEffect(isAnimating ? 1.1 : 0.9)
                    }
                    .padding()

                    Text(viewModel.lockInRewardMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Rewards List
                    VStack(alignment: .leading, spacing: 15) {
                        RewardRow(icon: "star.fill", text: "+1000 XP", color: .blue)
                        RewardRow(icon: "bitcoinsign.circle.fill", text: "+500 Gold", color: .yellow)
                        RewardRow(icon: "heart.fill", text: "+10 Vitality", color: .red)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)

                    Button(action: {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        withAnimation {
                            viewModel.showingLockInReward = false
                        }
                    }, label: {
                        Text("COLLECT REWARDS")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 40)
                            .background(Color.yellow)
                            .cornerRadius(30)
                            .shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 5)
                    })
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
            impactHeavy.impactOccurred()

            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3)) {
                showContent = true
            }

            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct RewardRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(text)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    let vm = UserViewModel.preview
    vm.lockInRewardMessage = "Challenge Complete! You earned 1000 XP, 500 Gold, and the 7-Day Trophy!"
    return LockInRewardOverlay(viewModel: vm)
}
