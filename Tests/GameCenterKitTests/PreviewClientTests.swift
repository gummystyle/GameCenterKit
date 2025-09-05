import Testing
import GameKit
@testable import GameCenterKit

@Suite("Preview client")
struct PreviewClientTests {
  
  @Test("Defaults: not authenticated")
  func testNotAuthenticatedByDefault() async {
    #expect(GameCenterClient.preview.isAuthenticated() == false)
  }

  @Test("Authenticate returns Preview player")
  func testAuthenticatePreviewReturnsPlayer() async throws {
    let player = try await GameCenterClient.preview.authenticate({ nil })
    #expect(player.displayName == "Preview")
    #expect(player.playerID == "PREVIEW")
  }

  @Test("No-op operations don't throw")
  func testPreviewClientNoOpOperationsDontThrow() async throws {
    try await GameCenterClient.preview.presentDashboard(.achievements, { nil })
    try await GameCenterClient.preview.submitScore(1, [LeaderboardID("lb")], 0)
    try await GameCenterClient.preview.reportAchievement(AchievementID("ach"), 100, true)
    _ = try await GameCenterClient.preview.loadAchievements(false)
    try await GameCenterClient.preview.resetAchievements()
    await GameCenterClient.preview.setAccessPoint(true, .topLeading, true)
  }
}
