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

/// A small client facade you can inject or mock without exposing the underlying actor.
///
/// Prefer using ``GameCenterClient`` in app code and tests; the implementation is provided by
/// ``GameCenterClient/live`` which forwards to ``GameCenterService``.
public struct GameCenterClient: Sendable {
  /// Returns whether the local player is authenticated.
  public var isAuthenticated: @Sendable () -> Bool
  /// Authenticates the local player, optionally providing a presenter closure.
  public var authenticate: @Sendable (_ presenter: @escaping @MainActor () -> UIViewController?) async throws -> Player
  /// Presents the dashboard or a specific leaderboard.
  public var presentDashboard: @Sendable (_ mode: DashboardMode, _ presenter: @escaping @MainActor () -> UIViewController?) async throws -> Void
  /// Submits a score to one or more leaderboards.
  public var submitScore: @Sendable (_ score: Int, _ leaderboards: [LeaderboardID], _ context: Int) async throws -> Void
  /// Reports progress for an achievement.
  public var reportAchievement: @Sendable (_ id: AchievementID, _ percentComplete: Double, _ showsBanner: Bool) async throws -> Void
  /// Loads achievements, optionally forcing a reload.
  public var loadAchievements: @Sendable (_ forceReload: Bool) async throws -> [AchievementProgress]
  /// Resets all achievement progress.
  public var resetAchievements: @Sendable () async throws -> Void
  /// Configures the Game Center Access Point.
  public var setAccessPoint: @Sendable (_ isActive: Bool, _ location: AccessPointLocation, _ showsHighlights: Bool) async -> Void

  /// Creates a ``GameCenterClient`` by supplying implementations for each operation.
  ///
  /// Most apps should use ``GameCenterClient/live``. Supplying a custom initializer is useful
  /// in tests or previews.
  public init(
    isAuthenticated: @escaping @Sendable () -> Bool,
    authenticate: @escaping @Sendable (@escaping @MainActor () -> UIViewController?) async throws -> Player,
    presentDashboard: @escaping @Sendable (DashboardMode, @escaping @MainActor () -> UIViewController?) async throws -> Void,
    submitScore: @escaping @Sendable (Int, [LeaderboardID], Int) async throws -> Void,
    reportAchievement: @escaping @Sendable (AchievementID, Double, Bool) async throws -> Void,
    loadAchievements: @escaping @Sendable (Bool) async throws -> [AchievementProgress],
    resetAchievements: @escaping @Sendable () async throws -> Void,
    setAccessPoint: @escaping @Sendable (Bool, AccessPointLocation, Bool) async -> Void
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

  /// The live client that forwards to ``GameCenterService/shared``.
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
        await service.setAccessPoint(active: isActive, location: location, showHighlights: showsHighlights)
      }
    )
  }()

  /// A preview/mock client with no-op behavior, suitable for SwiftUI previews.
  public static let preview: GameCenterClient = .init(
    isAuthenticated: { false },
    authenticate: { _ in Player(displayName: "Preview", playerID: "PREVIEW") },
    presentDashboard: { _, _ in },
    submitScore: { _, _, _ in },
    reportAchievement: { _, _, _ in },
    loadAchievements: { _ in [] },
    resetAchievements: {},
    setAccessPoint: { _, _, _ in }
  )
}

public extension GameCenterClient {
  /// Authenticates the local player without explicitly supplying a presenter.
  /// The service will attempt to locate a presenter automatically.
  @inlinable
  func authenticate() async throws -> Player {
    try await authenticate { nil }
  }

  /// Presents the Game Center dashboard without explicitly supplying a presenter.
  /// The service will attempt to locate a presenter automatically.
  @inlinable
  func presentDashboard(_ mode: DashboardMode) async throws {
    try await presentDashboard(mode) { nil }
  }
}

public extension EnvironmentValues {
  /// Access to the ``GameCenterClient`` via SwiftUI environment.
  var gameCenterClient: GameCenterClient {
    get { self[GameCenterClientKey.self] }
    set { self[GameCenterClientKey.self] = newValue }
  }
}

private struct GameCenterClientKey: EnvironmentKey {
  static let defaultValue: GameCenterClient = .live
}

#if canImport(Dependencies)
import Dependencies

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
