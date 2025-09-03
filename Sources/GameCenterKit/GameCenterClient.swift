//
//  GameCenterClient.swift
//  GameCenterKit
//
//  Created by Daniel Birkas on 2025-09-03.
//

import Foundation
import GameKit
import SwiftUI
import UIKit

/// Small client facade so you can inject or mock it in your app without exposing the actor.
public struct GameCenterClient: Sendable {
  public var isAuthenticated: @Sendable () -> Bool
  public var authenticate: @Sendable (_ presenter: @escaping @MainActor () -> UIViewController?) async throws -> Player
  public var presentDashboard: @Sendable (_ mode: DashboardMode, _ presenter: @escaping @MainActor () -> UIViewController?) async throws -> Void
  public var submitScore: @Sendable (_ score: Int, _ leaderboards: [LeaderboardID], _ context: Int) async throws -> Void
  public var reportAchievement: @Sendable (_ id: AchievementID, _ percentComplete: Double, _ showsBanner: Bool) async throws -> Void
  public var loadAchievements: @Sendable (_ forceReload: Bool) async throws -> [AchievementProgress]
  public var resetAchievements: @Sendable () async throws -> Void
  public var setAccessPoint: @Sendable (_ isActive: Bool, _ location: GKAccessPoint.Location, _ showsHighlights: Bool) async -> Void

  public init(
    isAuthenticated: @escaping @Sendable () -> Bool,
    authenticate: @escaping @Sendable (@escaping @MainActor () -> UIViewController?) async throws -> Player,
    presentDashboard: @escaping @Sendable (DashboardMode, @escaping @MainActor () -> UIViewController?) async throws -> Void,
    submitScore: @escaping @Sendable (Int, [LeaderboardID], Int) async throws -> Void,
    reportAchievement: @escaping @Sendable (AchievementID, Double, Bool) async throws -> Void,
    loadAchievements: @escaping @Sendable (Bool) async throws -> [AchievementProgress],
    resetAchievements: @escaping @Sendable () async throws -> Void,
    setAccessPoint: @escaping @Sendable (Bool, GKAccessPoint.Location, Bool) async -> Void
  ) {
    self.isAuthenticated = isAuthenticated
    self.authenticate = authenticate
    self.presentDashboard = presentDashboard
    self.submitScore = submitScore
    self.reportAchievement = reportAchievement
    self.loadAchievements = loadAchievements
    self.resetAchievements = resetAchievements
    self.setAccessPoint = setAccessPoint
  }

  public static let live: GameCenterClient = {
    let service = GameCenterService.shared
    return GameCenterClient(
      isAuthenticated: { service.isAuthenticated },
      authenticate: { presenter in
        try await service.authenticate(presenter: presenter)
      },
      presentDashboard: { mode, presenter in
        try await service.presentDashboard(mode, presenter: presenter)
      },
      submitScore: { score, leaderboards, context in
        try await service.submit(score: score, to: leaderboards, context: context)
      },
      reportAchievement: { id, percentComplete, showsBanner in
        try await service.reportAchievement(id, percentComplete: percentComplete, showsBanner: showsBanner)
      },
      loadAchievements: { forceReload in
        try await service.loadAchievements(forceReload: forceReload)
      },
      resetAchievements: {
        try await service.resetAchievements()
      },
      setAccessPoint: { isActive, location, showsHighlights in
        await MainActor.run {
          service.setAccessPoint(active: isActive, location: location, showHighlights: showsHighlights)
        }
      }
    )
  }()
}

public extension EnvironmentValues {
  var gameCenterClient: GameCenterClient {
    get { self[GameCenterClientKey.self] }
    set { self[GameCenterClientKey.self] = newValue }
  }
}

private struct GameCenterClientKey: EnvironmentKey {
  static let defaultValue: GameCenterClient = .live
}

#if canImport(ComposableArchitecture)
import ComposableArchitecture

public enum GameCenterDependencyKey: DependencyKey {
  public static var liveValue: GameCenterClient { .live }
  public static var previewValue: GameCenterClient { .preview }
  public static var testValue: GameCenterClient {
    .init(
      isAuthenticated: { false },
      authenticate: { _ in Player(displayName: "Test", playerID: "TEST") },
      presentDashboard: { _, _ in },
      submitScore: { _, _, _ in },
      reportAchievement: { _, _, _ in },
      loadAchievements: { _ in [] },
      resetAchievements: {},
      setAccessPoint: { _, _, _ in }
    )
  }
}

public extension DependencyValues {
  var gameCenter: GameCenterClient {
    get { self[GameCenterDependencyKey.self] }
    set { self[GameCenterDependencyKey.self] = newValue }
  }
}
#endif
