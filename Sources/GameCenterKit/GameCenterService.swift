//
//  GameCenterService.swift
//  GameCenterKit
//
//  Created by Daniel Birkas on 2025-09-03.
//

import Foundation
import GameKit
import UIKit

/// Concurrency-safe facade over GameKit.
///
/// Handles authentication, UI presentation, score submission, achievement reporting,
/// and access point control. Internally caches achievement data for short periods
/// to minimize network calls.
public actor GameCenterService {
  /// Shared live instance for convenience.
  public static let shared = GameCenterService()

  public init() {}

  // MARK: - Authentication

  /// Indicates whether the local player is currently authenticated with Game Center.
  public nonisolated var isAuthenticated: Bool {
    GKLocalPlayer.local.isAuthenticated
  }

  /// Authenticates the local player, presenting Apple's UI if needed.
  ///
  /// GameKit may provide a view controller to present. If so, the provided `presenter`
  /// closure is used to obtain a `UIViewController` to present from; if no presenter is
  /// supplied, the service attempts to find the key window's root view controller.
  ///
  /// - Parameter presenter: Optional closure returning a presenter view controller on the main actor.
  /// - Returns: A lightweight ``Player`` value when authentication succeeds.
  /// - Throws: ``GameCenterKitError`` if the user cancels or no valid presenter is available,
  ///   or an underlying GameKit error.
  public func authenticate(
    presenter: (@MainActor () -> UIViewController?)? = nil
  ) async throws -> Player {
    // Fast-path: already authenticated
    if GKLocalPlayer.local.isAuthenticated {
      let player = GKLocalPlayer.local
      return Player(displayName: player.displayName, playerID: player.gamePlayerID)
    }

    // Coalesce concurrent authenticate calls onto the same in-flight task
    if let task = authenticationTask {
      return try await task.value
    }

    let task = Task { () throws -> Player in
      try await withCheckedThrowingContinuation { continuation in
        // Hop onto the service actor to install the handler
        Task { [weak self] in
          await self?.startAuthentication(presenter: presenter, continuation: continuation)
        }
      }
    }

    authenticationTask = task
    do {
      defer { self.authenticationTask = nil }
      let player = try await task.value
      // Clear achievement cache after a successful authentication on the actor.
      achievementsCache.removeAll()
      return player
    }
  }

  // MARK: - Dashboard

  /// Presents the Game Center dashboard or a specific leaderboard.
  ///
  /// - Parameters:
  ///   - mode: ``DashboardMode`` describing which UI to show.
  ///   - presenter: Optional closure returning a presenter view controller on the main actor.
  /// - Throws: ``GameCenterKitError.notAuthenticated`` if the local player is not
  ///   signed in, or ``GameCenterKitError.invalidPresentationContext`` if a presenter
  ///   cannot be determined.
  public func presentDashboard(
    _ mode: DashboardMode,
    presenter: (@MainActor () -> UIViewController?)? = nil
  ) async throws {
    guard isAuthenticated else { throw GameCenterKitError.notAuthenticated }

    try await MainActor.run {
      let presenter = presenter?() ?? Self.topViewController()
      guard let presenter else { throw GameCenterKitError.invalidPresentationContext }

      let viewController: GKGameCenterViewController = switch mode {
      case let .leaderboards(id):
        if let id {
          GKGameCenterViewController(
            leaderboardID: id.rawValue,
            playerScope: .global,
            timeScope: .allTime
          )
        } else {
          GKGameCenterViewController(state: .leaderboards)
        }
      case .achievements:
        GKGameCenterViewController(state: .achievements)
      }

      viewController.gameCenterDelegate = GameCenterControllerDelegate.shared
      presenter.present(viewController, animated: true)
    }
  }

  // MARK: - Scores

  /// Submits a score to one or more leaderboards.
  ///
  /// - Parameters:
  ///   - score: The integer score value to submit.
  ///   - leaderboards: The target leaderboard identifiers.
  ///   - context: Optional context value for the score (defaults to 0).
  /// - Throws: An error if submission fails.
  public func submit(
    score: Int,
    to leaderboards: [LeaderboardID],
    context: Int = 0
  ) async throws {
    guard isAuthenticated else { throw GameCenterKitError.notAuthenticated }
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

  /// Reports achievement progress.
  ///
  /// - Parameters:
  ///   - id: The achievement identifier.
  ///   - percentComplete: Completion percent in the range 0...100.
  ///   - showsBanner: Whether Game Center should show a completion banner.
  /// - Throws: An error if reporting fails.
  public func reportAchievement(
    _ id: AchievementID,
    percentComplete: Double,
    showsBanner: Bool = true
  ) async throws {
    guard isAuthenticated else { throw GameCenterKitError.notAuthenticated }
    let achievement = GKAchievement(identifier: id.rawValue)
    let clampedPercent = max(0, min(100, percentComplete))
    achievement.percentComplete = clampedPercent
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

  /// Loads achievements for the local player.
  ///
  /// Results are cached briefly; pass `forceReload = true` to bypass the cache.
  ///
  /// - Parameter forceReload: Whether to force a network load.
  /// - Returns: A list of ``AchievementProgress`` values.
  /// - Throws: An error if loading fails.
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

  /// Resets all achievement progress for the local player.
  ///
  /// - Throws: An error if the reset fails.
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

  /// Configures the floating Game Center Access Point.
  ///
  /// No effect while the Game Center UI is currently presenting.
  ///
  /// - Parameters:
  ///   - active: Whether the access point should be visible.
  ///   - location: Screen corner for the access point.
  ///   - showHighlights: Whether to show highlight content in the access point.
  @MainActor
  public func setAccessPoint(
    active: Bool,
    location: AccessPointLocation = .topLeading,
    showHighlights: Bool = true
  ) {
    guard GKAccessPoint.shared.isPresentingGameCenter == false else { return }

    GKAccessPoint.shared.location = Self.map(location)
    GKAccessPoint.shared.showHighlights = showHighlights
    GKAccessPoint.shared.isActive = active
  }

  // MARK: - Helpers

  /// Maps a raw error to a ``GameCenterKitError`` when possible.
  static func map(_ error: Error) -> Error {
    let ns = error as NSError
    if ns.domain == GKErrorDomain, let code = GKError.Code(rawValue: ns.code) {
      switch code {
      case .notAuthenticated:
        return GameCenterKitError.notAuthenticated
      case .cancelled, .userDenied:
        return GameCenterKitError.cancelled
      case .apiNotAvailable:
        return GameCenterKitError.gameCenterUnavailable
      default:
        return GameCenterKitError.underlyingError(ns.localizedDescription)
      }
    }

    if let gameKitError = error as? GKError {
      return GameCenterKitError.underlyingError(gameKitError.localizedDescription)
    }

    return error
  }

  /// Maps a ``GKAchievement`` to a lightweight ``AchievementProgress`` value.
  static func map(_ achievement: GKAchievement) -> AchievementProgress {
    AchievementProgress(
      id: .init(achievement.identifier),
      percent: achievement.percentComplete,
      isCompleted: achievement.isCompleted,
      showsCompletionBanner: achievement.showsCompletionBanner
    )
  }

  /// Attempts to locate the top-most presenter from the key window.
  ///
  /// Used as a best-effort fallback when no presenter closure is provided.
  @MainActor
  static func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?
      .rootViewController
    return topViewController(from: root)
  }

  @MainActor
  static func topViewController(from root: UIViewController?) -> UIViewController? {
    guard let root else { return nil }
    if let presented = root.presentedViewController {
      return topViewController(from: presented)
    }
    if let navigationController = root as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController ?? navigationController.topViewController) ?? navigationController
    }
    if let tabBarController = root as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController) ?? tabBarController
    }
    if let splitViewController = root as? UISplitViewController {
      return topViewController(from: splitViewController.viewControllers.last) ?? splitViewController
    }
    return root
  }

  // MARK: - Authentication internals

  private var authenticationContinuation: CheckedContinuation<Player, Error>?
  private var didResumeAuthentication = false

  private func startAuthentication(
    presenter: (@MainActor () -> UIViewController?)?,
    continuation: CheckedContinuation<Player, Error>
  ) {
    // actor-isolated
    authenticationContinuation = continuation
    didResumeAuthentication = false

    GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
      // Bounce back to the service actor for serialized handling
      Task { [weak self] in
        await self?.handleAuthenticationCallback(
          viewController: viewController,
          error: error,
          presenter: presenter
        )
      }
    }
  }

  private func resumeAuthenticationOnce(_ result: Result<Player, Error>) {
    guard didResumeAuthentication == false else { return }
    didResumeAuthentication = true
    // Detach further callbacks
    GKLocalPlayer.local.authenticateHandler = nil

    guard let continuation = authenticationContinuation else { return }
    authenticationContinuation = nil
    switch result {
    case let .success(player):
      continuation.resume(returning: player)
    case let .failure(error):
      continuation.resume(throwing: error)
    }
  }

  private func handleAuthenticationCallback(
    viewController: UIViewController?,
    error: Error?,
    presenter: (@MainActor () -> UIViewController?)?
  ) async {
    if let error {
      resumeAuthenticationOnce(.failure(Self.map(error)))
      return
    }

    if let viewController {
      // Present UI on the main actor; evaluate success on actor afterwards.
      let presented: Bool = await MainActor.run {
        let presentingViewController = presenter?() ?? Self.topViewController()
        guard let presentingViewController else { return false }
        presentingViewController.present(viewController, animated: true)
        return true
      }
      if presented == false {
        resumeAuthenticationOnce(.failure(GameCenterKitError.invalidPresentationContext))
      }
      return
    }

    let player = GKLocalPlayer.local
    if player.isAuthenticated {
      resumeAuthenticationOnce(
        .success(
          Player(
            displayName: player.displayName,
            playerID: player.gamePlayerID
          )
        )
      )
    } else {
      resumeAuthenticationOnce(.failure(GameCenterKitError.cancelled))
    }
  }

  // MARK: - Caches

  private var achievementsCache: [String: GKAchievement] = [:]
  private var lastAchievementsLoad = Date.distantPast
  private var authenticationTask: Task<Player, Error>?
}

/// Single shared delegate for Apple's dashboard view controller that dismisses on finish.
final class GameCenterControllerDelegate: NSObject, GKGameCenterControllerDelegate {
  /// Shared instance used by presented ``GKGameCenterViewController`` instances.
  @MainActor static let shared = GameCenterControllerDelegate()

  /// Dismisses the Game Center UI when the user finishes.
  func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    Task { @MainActor in
      gameCenterViewController.dismiss(animated: true)
    }
  }
}

// MARK: - Private mappings

extension GameCenterService {
  @MainActor
  static func map(_ location: AccessPointLocation) -> GKAccessPoint.Location {
    switch location {
    case .topLeading: .topLeading
    case .topTrailing: .topTrailing
    case .bottomLeading: .bottomLeading
    case .bottomTrailing: .bottomTrailing
    }
  }
}
