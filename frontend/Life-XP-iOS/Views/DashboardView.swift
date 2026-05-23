import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject var healthKitManager: HealthKitManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Lock In Banner
                if let challenge = viewModel.user.activeLockIn {
                    LockInBanner(challenge: challenge)
                }

                // Character Header
                HStack(alignment: .center, spacing: 15) {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("👤")
                                .font(.system(size: 40))
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(viewModel.user.name)
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Level \(viewModel.user.level)")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: "banknote.fill")
                                .foregroundColor(.green)
                            Text("\(viewModel.user.gold) Gold")
                                .font(.caption)
                                .fontWeight(.bold)
                        }

                        // XP Bar
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: viewModel.user.xpProgress)
                                .tint(.blue)

                            Text("\(viewModel.user.experience) / \(viewModel.user.xpToNextLevel) XP")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)).shadow(radius: 2))
                .padding(.horizontal)

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    StatCard(title: "Strength", value: viewModel.user.strength, icon: "figure.walk", color: .red)
                    StatCard(title: "Intelligence", value: viewModel.user.intelligence, icon: "brain", color: .purple)
                    StatCard(title: "Vitality", value: viewModel.user.vitality, icon: "heart.fill", color: .green)
                    StatCard(title: "Charisma", value: viewModel.user.charisma, icon: "star.fill", color: .yellow)
                }
                .padding(.horizontal)

                // Health Data
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Today's Health Data")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()

                        syncStatusIndicator

                        Button(action: fetchAndSync, label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        })
                    }
                    .padding(.horizontal)

                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            HealthStatCard(
                                title: "Steps",
                                value: "\(healthKitManager.stepCount)",
                                icon: "shoeprints.fill"
                            )
                            HealthStatCard(
                                title: "Active Burn",
                                value: String(format: "%.0f kcal", healthKitManager.activeEnergy),
                                icon: "flame.fill"
                            )
                        }
                        HStack(spacing: 15) {
                            HealthStatCard(
                                title: "Sleep",
                                value: String(format: "%.1f hrs", healthKitManager.sleepHours),
                                icon: "bed.double.fill"
                            )
                            HealthStatCard(
                                title: "Water",
                                value: String(format: "%.2f L", healthKitManager.waterIntake),
                                icon: "drop.fill"
                            )
                        }
                    }
                    .padding(.horizontal)

                    if let lastSync = viewModel.user.lastSyncDate {
                        Text("Last Synced: \(lastSync, style: .time)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }

                // Charisma Perks
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles").foregroundColor(.yellow)
                        Text("Charisma Perks")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 8) {
                        CharismaPerkRow(
                            icon: "banknote.fill",
                            iconColor: .green,
                            label: "Gold per Habit",
                            value: "+\(viewModel.charismaGoldBonus) bonus"
                        )
                        CharismaPerkRow(
                            icon: "person.2.fill",
                            iconColor: .orange,
                            label: "Social Habits",
                            value: "Always +1 Charisma"
                        )
                        CharismaPerkRow(
                            icon: "figure.walk",
                            iconColor: .red,
                            label: "Physical/Mental/Health",
                            value: "1-in-3 stat boost"
                        )
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(Color(.systemBackground)).shadow(radius: 2))
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            guard !viewModel.isSyncing else { return }
            fetchAndSync()
        }
    }

    private func fetchAndSync() {
        healthKitManager.fetchTodayHealthData {
            viewModel.syncHealthData(
                steps: healthKitManager.stepCount,
                calories: healthKitManager.activeEnergy,
                sleep: healthKitManager.sleepHours,
                water: healthKitManager.waterIntake
            )
        }
    }

    @ViewBuilder
    private var syncStatusIndicator: some View {
        if viewModel.isSyncing {
            ProgressView()
                .scaleEffect(0.8)
        } else if viewModel.lastCloudSync != nil {
            Image(systemName: "checkmark.icloud.fill")
                .foregroundColor(.green)
                .font(.caption)
        } else {
            Image(systemName: "icloud")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct CharismaPerkRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(iconColor).frame(width: 20)
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(.secondary)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }
}

#Preview {
    DashboardView(viewModel: .preview, healthKitManager: HealthKitManager())
}

struct HealthStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
            }
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }
}

struct LockInBanner: View {
    let challenge: LockInChallenge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOCK IN ACTIVE")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.orange)

                    Text("Day \(currentDay) of \(challenge.durationDays)")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<challenge.maxStrikes, id: \.self) { index in
                        Image(systemName: index < challenge.strikesCount ? "heart.slash.fill" : "heart.fill")
                            .foregroundColor(index < challenge.strikesCount ? .gray : .red)
                    }
                }
            }

            ProgressView(value: progress)
                .tint(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                )
                .shadow(radius: 5)
        )
        .padding(.horizontal)
    }

    private var currentDay: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: challenge.startDate)
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.day], from: start, to: today)
        return min((components.day ?? 0) + 1, challenge.durationDays)
    }

    private var progress: Double {
        Double(currentDay) / Double(challenge.durationDays)
    }
}
