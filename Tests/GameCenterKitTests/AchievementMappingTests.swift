import Testing
import GameKit
@testable import GameCenterKit

@Suite("Achievement mapping")
struct AchievementMappingTests {

  @Test("GKAchievement to AchievementProgress mapping")
  func testMapsGKAchievementToAchievementProgress() {
    let achievement = GKAchievement(identifier: "first_win")
    achievement.percentComplete = 100
    achievement.showsCompletionBanner = true

    let progress = GameCenterService.map(achievement)
    #expect(progress.id == AchievementID("first_win"))
    #expect(progress.percent == 100)
    #expect(progress.isCompleted == true)
    #expect(progress.showsCompletionBanner == true)
  }
}
