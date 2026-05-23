import Foundation

extension UserViewModel {
    var publicProfileRecordName: String {
        if let name = UserDefaults.standard.string(forKey: "PublicProfileRecordName") { return name }
        let name = UUID().uuidString
        UserDefaults.standard.set(name, forKey: "PublicProfileRecordName")
        return name
    }

    var charismaGoldBonus: Int { user.charisma / 10 }

    func fetchLeaderboard() {
        isLoadingLeaderboard = true
        CloudKitManager.shared.fetchLeaderboard { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingLeaderboard = false
                if case .success(let profiles) = result {
                    self?.leaderboard = profiles
                }
            }
        }
    }

    func uploadPublicProfile() {
        CloudKitManager.shared.savePublicProfile(
            recordName: publicProfileRecordName,
            name: user.name,
            level: user.level,
            charisma: user.charisma
        ) { error in
            if let error = error {
                print("Public Profile Upload Error: \(error.localizedDescription)")
            }
        }
    }
}
