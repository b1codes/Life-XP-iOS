import Foundation

extension UserViewModel {
    func checkMilestones(for goal: Goal) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        let percent = goal.progressPercent

        for threshold in [25, 50, 75, 100] {
            if percent >= threshold && !goals[index].awardedMilestones.contains(threshold) {
                goals[index].awardedMilestones.insert(threshold)
                if threshold == 100 {
                    goals[index].isCompleted = true
                }
                awardMilestone(goals[index], threshold: threshold)
            }
        }
    }

    private func awardMilestone(_ goal: Goal, threshold: Int) {
        let xpAmount = milestoneXP(for: threshold)
        let gold = milestoneGold(for: threshold)
        let statBoost = milestoneStatBoost(for: threshold)
        addExperience(xpAmount)
        user.gold += gold
        applyStatBoost(statBoost, for: goal.category)

        if threshold == 100 {
            let trophy = Item(
                name: "\(goal.title) Trophy",
                description: "Completed: \(goal.title)",
                icon: "trophy.fill",
                price: 0,
                statBoost: nil,
                boostAmount: 0
            )
            user.inventory.append(trophy)
        }

        lastMilestoneMessage = "\(goal.title) \(threshold)% complete! +\(xpAmount) XP, +\(gold) Gold"
        showingMilestoneReward = true
    }

    private func milestoneXP(for threshold: Int) -> Int {
        switch threshold {
        case 25:  return 25
        case 50:  return 50
        case 75:  return 100
        case 100: return 200
        default:  return 0
        }
    }

    private func milestoneGold(for threshold: Int) -> Int {
        switch threshold {
        case 25:  return 10
        case 50:  return 25
        case 75:  return 50
        case 100: return 100
        default:  return 0
        }
    }

    private func milestoneStatBoost(for threshold: Int) -> Int {
        switch threshold {
        case 25:  return 1
        case 50:  return 2
        case 75:  return 3
        case 100: return 5
        default:  return 0
        }
    }

    private func applyStatBoost(_ amount: Int, for category: GoalCategory) {
        switch category {
        case .fitness:   user.strength += amount
        case .wellness:  user.vitality += amount
        case .learning:  user.intelligence += amount
        case .financial:
            user.intelligence += (amount + 1) / 2
            user.charisma += amount / 2
        case .social:    user.charisma += amount
        }
    }
}
