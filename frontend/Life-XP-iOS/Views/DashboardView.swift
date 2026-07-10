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
                    ZStack {
                        Circle()
                            .fill(Color.llcGlassFill)
                        Circle()
                            .stroke(Color.llcGlassBorder, lineWidth: 0.5)
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                    }
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 80, height: 80)

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
                                .tint(.primary)

                            Text("\(viewModel.user.experience) / \(viewModel.user.xpToNextLevel) XP")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .llcGlass(borderRadius: 15)
                .padding(.horizontal)

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    StatCard(title: "Strength", value: viewModel.user.strength, icon: "figure.walk", color: .llcStatStrength)
                    StatCard(title: "Intelligence", value: viewModel.user.intelligence, icon: "brain", color: .llcStatIntelligence)
                    StatCard(title: "Vitality", value: viewModel.user.vitality, icon: "heart.fill", color: .llcStatVitality)
                    StatCard(title: "Charisma", value: viewModel.user.charisma, icon: "star.fill", color: .llcStatCharisma)
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
                                .foregroundStyle(.primary)
                                .padding(8)
                        })
                        .buttonStyle(.plain)
                        .background(Color.llcGlassFill, in: Circle())
                        .overlay(Circle().stroke(Color.llcGlassBorder, lineWidth: 0.5))
                        .llcThermalGlow(diameter: 70)
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
                    .llcGlass(borderRadius: 15)
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
        .llcGlass(borderRadius: 12)
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
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
            }
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .llcGlass(borderRadius: 12)
    }
}

struct LockInBanner: View {
    let challenge: LockInChallenge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOCK IN ACTIVE")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(.primary)

                    Text("Day \(currentDay) of \(challenge.durationDays)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<challenge.maxStrikes, id: \.self) { index in
                        Image(systemName: index < challenge.strikesCount ? "heart.slash.fill" : "heart.fill")
                            .foregroundStyle(index < challenge.strikesCount ? Color.secondary : Color.red)
                    }
                }
            }

            ProgressView(value: progress)
                .tint(.primary)
        }
        .padding()
        .background(alignment: .topLeading) {
            // Active challenge reads as energy in progress — a contained
            // ambient ember, not a static orange/yellow accent border.
            ThermalBurstView(diameter: 160, restingOpacity: 0.3)
                .offset(x: -40, y: -40)
                .allowsHitTesting(false)
        }
        .llcGlass(borderRadius: 15)
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
