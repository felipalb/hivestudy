import Foundation
import HiveEngine

/// Manages persistent progress in the Campaign mode ("Jornada da Colmeia").
@MainActor
final class CampaignPersistence {
    private static let unlockedLevelKey = "hive.campaign.unlockedLevel.v1"
    private static let starsKey = "hive.campaign.stars.v1"

    /// The highest level index the player has unlocked (1 to 5).
    static var unlockedLevel: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: unlockedLevelKey)
            return max(1, saved)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: unlockedLevelKey)
        }
    }

    /// Dictionary mapping level ID (1..5) to stars earned (1..3).
    static var earnedStars: [Int: Int] {
        get {
            guard let data = UserDefaults.standard.data(forKey: starsKey),
                  let dict = try? JSONDecoder().decode([Int: Int].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: starsKey)
            }
        }
    }

    /// Marks a level as completed with the given star rating and unlocks the next level.
    static func complete(levelID: Int, turns: Int, parTurns: Int) {
        var stars = 1
        if turns <= parTurns {
            stars = 3
        } else if turns <= parTurns + 4 {
            stars = 2
        }

        var currentStars = earnedStars
        let prev = currentStars[levelID] ?? 0
        currentStars[levelID] = max(prev, stars)
        earnedStars = currentStars

        if levelID >= unlockedLevel && levelID < CampaignLevel.allLevels.count {
            unlockedLevel = levelID + 1
        }
    }

    /// Resets all campaign progress (useful for testing or profile reset).
    static func reset() {
        UserDefaults.standard.removeObject(forKey: unlockedLevelKey)
        UserDefaults.standard.removeObject(forKey: starsKey)
    }
}
