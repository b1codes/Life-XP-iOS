//
//  ContentView.swift
//  Life-XP-iOS
//
//  Created by Brandon Lamer-Connolly on 1/10/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var healthKitManager = HealthKitManager()

    var body: some View {
        ZStack {
            TabView {
                DashboardView(viewModel: userViewModel, healthKitManager: healthKitManager)
                    .tabItem {
                        Label("Dashboard", systemImage: "person.circle.fill")
                    }

                HabitListView(viewModel: userViewModel, healthKitManager: healthKitManager)
                    .tabItem {
                        Label("Habits", systemImage: "checkmark.circle.fill")
                    }

                BreakItView(viewModel: userViewModel)
                    .tabItem {
                        Label("Break It", systemImage: "link.slash")
                    }

                GoalsView(viewModel: userViewModel)
                    .tabItem {
                        Label("Goals", systemImage: "flag.fill")
                    }

                SocialView(viewModel: userViewModel)
                    .tabItem {
                        Label("Social", systemImage: "person.2.fill")
                    }

                InventoryView(viewModel: userViewModel)
                    .tabItem {
                        Label("Inventory", systemImage: "shippingbox.fill")
                    }

                SettingsView(viewModel: userViewModel, healthKitManager: healthKitManager)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }

            // Level Up Animation Overlay
            if userViewModel.showingLevelUp {
                LevelUpOverlay(level: userViewModel.lastLeveledUpTo, isShowing: $userViewModel.showingLevelUp)
                    .transition(.opacity)
                    .zIndex(100)
            }

            // Lock In Reward Overlay
            if userViewModel.showingLockInReward {
                LockInRewardOverlay(viewModel: userViewModel)
                    .transition(.opacity)
                    .zIndex(110)
            }
        }
        .onAppear {
            healthKitManager.requestAuthorization { success, _ in
                if success {
                    healthKitManager.fetchTodayHealthData()
                    userViewModel.refreshHealthKitGoals(using: healthKitManager)
                    userViewModel.evaluateHealthHabits(using: healthKitManager)
                }
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject var healthKitManager: HealthKitManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Cloud Sync")) {
                    HStack {
                        Text("Cloud Status")
                        Spacer()
                        if viewModel.isSyncing {
                            ProgressView()
                        } else {
                            Text(viewModel.lastCloudSync != nil ? "Synced" : "Not Synced")
                                .foregroundColor(viewModel.lastCloudSync != nil ? .green : .secondary)
                        }
                    }

                    if let lastSync = viewModel.lastCloudSync {
                        Text("Last Cloud Sync: \(lastSync, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Sync Now") {
                        viewModel.fetchFromCloud()
                        viewModel.uploadToCloud()
                    }
                    .disabled(viewModel.isSyncing)
                }

                Section(header: Text("HealthKit Permissions")) {
                    HStack {
                        Text("Authorization Status")
                        Spacer()
                        Text(healthKitManager.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(healthKitManager.isAuthorized ? .green : .red)
                    }

                    Button("Request Permissions") {
                        if healthKitManager.isAuthorized {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } else {
                            healthKitManager.requestAuthorization { _, _ in }
                        }
                    }
                }

                Section(header: Text("Security")) {
                    Toggle("Require Biometric Lock", isOn: Binding(
                        get: { viewModel.requireBiometricLock },
                        set: { newValue in
                            viewModel.setBiometricLock(newValue) { success in
                                // State is automatically updated inside UserViewModel on success
                            }
                        }
                    ))
                    Text("Requires Face ID or Touch ID authentication to access the Break It section.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    let previewVM = UserViewModel.preview
    let previewHM = HealthKitManager()
    return ContentView()
        .environmentObject(previewVM) // Though currently it uses StateObject internally,
                               // usually we'd inject for better previews
}
