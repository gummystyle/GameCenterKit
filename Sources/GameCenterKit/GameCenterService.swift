//
//  GameCenterService.swift
//  GameCenterKit
//
//  Created by Daniel Birkas on 2025-09-03.
//

import Foundation
import GameKit
import UIKit

/// Concurrency-safe facade over GameKit. Holds caches and handles authentication and presentation.
public actor GameCenterService {
  public static let shared = GameCenterService()

  public init() {}

  // MARK: - Authentication

  public nonisolated var isAuthenticated: Bool {
    GKLocalPlayer.local.isAuthenticated
  }

  /// Authenticate the local player. Presents Apple's sheet if needed.
  /// - Parameter presenter: Optional closure to provide a presenting view controller.
  /// If `nil`, we look up the keyWindow root when needed.
  public func authenticate(
    presenter: (@MainActor () -> UIViewController?)? = nil
  ) async throws -> Player {
    try await withCheckedThrowingContinuation { continuation in
      let player = GKLocalPlayer.local
      player.authenticateHandler = { viewController, error in
        if let error {
          continuation.resume(throwing: Self.map(error))
          return
        }

        if let viewController {
          Task { @MainActor in
            let presenter = presenter?() ?? Self.topViewController()
            guard let presenter else {
              continuation.resume(throwing: GameCenterKitError.invalidPresentationContext)
              return
            }
            presenter.present(viewController, animated: true)
          }
          // Handler will be called again after user interaction.
          return
        }

        if player.isAuthenticated {
          self.achievementsCache.removeAll()
          continuation.resume(
            returning: Player(
              displayName: player.displayName,
              playerID: player.gamePlayerID
            )
          )
        } else {
          continuation.resume(throwing: GameCenterKitError.cancelled)
        }
      }
    }
  }

  // MARK: - Dashboard

  /// Presents the Game Center dashboard or a specific leaderboard.
  public func presentDashboard(
    _ mode: DashboardMode,
    presenter: (@MainActor () -> UIViewController?)? = nil
  ) async throws {
    guard isAuthenticated else { throw GameCenterKitError.notAuthenticated }

    try await MainActor.run {
      let presenter = presenter?() ?? Self.topViewController()
      guard let presenter else { throw GameCenterKitError.invalidPresentationContext }

      let viewController: GKGameCenterViewController
      switch mode {
      case let .leaderboards(id):
        if let id {
          viewController = GKGameCenterViewController(
            leaderboardID: id.rawValue,
            playerScope: .global,
            timeScope: .allTime
          )
        } else {
          viewController = GKGameCenterViewController(state: .leaderboards)
        }
      case .achievements:
        viewController = GKGameCenterViewController(state: .achievements)
      }

      viewController.gameCenterDelegate = GameCenterControllerDelegate.shared
      presenter.present(viewController, animated: true)
    }
  }

  // MARK: - Scores

  public func submit(
    score: Int,
    to leaderboards: [LeaderboardID],
    context: Int = 0
  ) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      GKLeaderboard.submitScore(
        score,
        context: context,
        player: GKLocalPlayer.local,
        leaderboardIDs: leaderboards.map { $0.rawValue }
      ) { error in
        if let error {
          continuation.resume(throwing: Self.map(error))
        } else {
          continuation.resume()
        }
      }
    }
  }

  // MARK: - Achievements

  public func reportAchievement(
    _ id: AchievementID,
    percentComplete: Double,
    showsBanner: Bool = true
  ) async throws {
    let achievement = GKAchievement(identifier: id.rawValue)
    achievement.percentComplete = percentComplete
    achievement.showsCompletionBanner = showsBanner

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      GKAchievement.report([achievement]) { error in
        if let error {
          continuation.resume(throwing: Self.map(error))
        } else {
          continuation.resume()
        }
      }
    }

    // Update cache optimistically
    achievementsCache[id.rawValue] = achievement
  }

  public func loadAchievements(
    forceReload: Bool = false
  ) async throws -> [AchievementProgress] {
    if !forceReload, Date().timeIntervalSince(lastAchievementsLoad) < 10, !achievementsCache.isEmpty {
      return achievementsCache.values.map(Self.map)
    }

    let achievements: [GKAchievement] = try await withCheckedThrowingContinuation { continuation in
      GKAchievement.loadAchievements { achievements, error in
        if let error {
          continuation.resume(throwing: Self.map(error))
        } else {
          continuation.resume(returning: achievements ?? [])
        }
      }
    }

    achievementsCache = Dictionary(uniqueKeysWithValues: achievements.map { ($0.identifier, $0) })
    lastAchievementsLoad = Date()
    return achievements.map(Self.map)
  }

  public func resetAchievements() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      GKAchievement.resetAchievements { error in
        if let error {
          continuation.resume(throwing: Self.map(error))
        } else {
          continuation.resume()
        }
      }
    }

    achievementsCache.removeAll()
  }

  // MARK: - Access Point

  @MainActor
  public func setAccessPoint(
    active: Bool,
    location: GKAccessPoint.Location = .topLeading,
    showHighlights: Bool = true
  ) {
    guard GKAccessPoint.shared.isPresentingGameCenter == false else { return }

    GKAccessPoint.shared.location = location
    GKAccessPoint.shared.showHighlights = showHighlights
    GKAccessPoint.shared.isActive = active
  }

  // MARK: - Helpers

  static func map(_ error: Error) -> Error {
    if let gameKitError = error as? GKError {
      // TODO: map more errors?
      switch gameKitError.errorCode {
      case GKError.notAuthenticated.rawValue:
        return GameCenterKitError.notAuthenticated
      default:
        return GameCenterKitError.underlyingError(gameKitError.localizedDescription)
      }
    }

    return error
  }

  static func map(_ achievement: GKAchievement) -> AchievementProgress {
    AchievementProgress(
      id: .init(achievement.identifier),
      percent: achievement.percentComplete,
      isCompleted: achievement.isCompleted,
      showsCompletionBanner: achievement.showsCompletionBanner
    )
  }

  @MainActor
  static func topViewController() -> UIViewController? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?
      .rootViewController
  }

  // MARK: - Caches

  private var achievementsCache: [String: GKAchievement] = [:]
  private var lastAchievementsLoad = Date.distantPast
}

/// Single shared delegate for Apple's dashboard ViewController.
final class GameCenterControllerDelegate: NSObject, GKGameCenterControllerDelegate {
  @MainActor static let shared = GameCenterControllerDelegate()

  func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    Task { @MainActor in
      gameCenterViewController.dismiss(animated: true)
    }
  }
}
