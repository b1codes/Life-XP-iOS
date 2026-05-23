import SwiftUI

struct SocialView: View {
    @ObservedObject var viewModel: UserViewModel

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Your Profile")) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.15)).frame(width: 44, height: 44)
                            Image(systemName: "person.fill").foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.user.name).font(.headline)
                            Text("Level \(viewModel.user.level)").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption2)
                                Text("\(viewModel.user.charisma)").font(.caption).fontWeight(.bold)
                            }
                            Text("Charisma").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button("Update Leaderboard Profile") {
                        viewModel.uploadPublicProfile()
                    }
                    .font(.subheadline)
                }

                Section {
                    if viewModel.isLoadingLeaderboard {
                        HStack {
                            Spacer()
                            ProgressView("Loading adventurers...")
                            Spacer()
                        }
                        .padding()
                    } else if viewModel.leaderboard.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.largeTitle).foregroundColor(.secondary)
                            Text("No adventurers found")
                                .font(.headline)
                            Text("Tap \"Update Leaderboard Profile\" above to appear here, then refresh.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { idx, profile in
                            LeaderboardRowView(
                                rank: idx + 1,
                                profile: profile,
                                isCurrentUser: profile.id == viewModel.publicProfileRecordName
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("Leaderboard — Top Adventurers")
                        Spacer()
                        if viewModel.isLoadingLeaderboard {
                            ProgressView().scaleEffect(0.7)
                        }
                    }
                }
            }
            .navigationTitle("Social")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.fetchLeaderboard()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(viewModel.isLoadingLeaderboard)
                }
            }
            .onAppear { viewModel.fetchLeaderboard() }
        }
    }
}

struct LeaderboardRowView: View {
    let rank: Int
    let profile: PublicProfile
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(rankColor.opacity(0.15)).frame(width: 36, height: 36)
                Text(rank <= 3 ? rankEmoji : "\(rank)")
                    .font(rank <= 3 ? .title3 : .headline)
                    .foregroundColor(rankColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(profile.displayName).font(.headline)
                    if isCurrentUser {
                        Text("(You)").font(.caption).foregroundColor(.blue)
                    }
                }
                Text("Level \(profile.level)").font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption2)
                    Text("\(profile.charisma)").font(.caption).fontWeight(.bold)
                }
                Text("CHA").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(isCurrentUser ? Color.blue.opacity(0.05) : Color(.systemBackground))
    }

    private var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(red: 0.6, green: 0.6, blue: 0.6)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .secondary
        }
    }
}

#Preview {
    SocialView(viewModel: .preview)
}
