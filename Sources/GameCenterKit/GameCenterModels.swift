//
//  GameCenterModels.swift
//  GameCenterKit
//
//  Created by Daniel Birkas on 2025-09-03.
//

import Foundation
import GameKit

/// Location for the floating Game Center Access Point.
///
/// This type mirrors the common positions supported by GameKit but avoids
/// leaking `GKAccessPoint.Location` through public APIs.
public enum AccessPointLocation: Sendable, Equatable {
  case topLeading
  case topTrailing
  case bottomLeading
  case bottomTrailing
}

/// A type-safe identifier for a Game Center leaderboard.
///
/// Wraps the string identifier you configure in App Store Connect.
/// Using a dedicated type helps avoid mixing up identifiers.
///
/// - SeeAlso: ``AchievementID``
/// - SeeAlso: ``DashboardMode``
public struct LeaderboardID: RawRepresentable, Hashable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

/// A type-safe identifier for a Game Center achievement.
///
/// Wraps the string identifier you configure in App Store Connect.
public struct AchievementID: RawRepresentable, Hashable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

/// Errors specific to GameCenterKit and bridged GameKit failures.
public enum GameCenterKitError: LocalizedError, Sendable {
  case notAuthenticated
  case cancelled
  case invalidPresentationContext
  case gameCenterUnavailable
  case underlyingError(String)

  public var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      "Game Center player is not authenticated."
    case .cancelled:
      "Game Center authentication was cancelled."
    case .invalidPresentationContext:
      "No view controller available to present Game Center UI."
    case .gameCenterUnavailable:
      "Game Center is not available on this device or is restricted."
    case let .underlyingError(message):
      message
    }
  }
}

/// Dashboard type to present via Game Center UI.
public enum DashboardMode: Sendable, Equatable {
  case leaderboards(LeaderboardID? = nil)
  case achievements
}

/// Lightweight value type for achievements so your app doesn't need to import GameKit in most places.
///
/// This value mirrors the essential fields from ``GKAchievement`` and is safe
/// to pass across concurrency boundaries.
public struct AchievementProgress: Equatable, Sendable {
  /// The achievement identifier.
  public var id: AchievementID
  /// Completion percentage in the range 0...100.
  public var percent: Double
  /// Whether the achievement is fully completed.
  public var isCompleted: Bool
  /// Whether Game Center should show a completion banner when reported.
  public var showsCompletionBanner: Bool

  public init(
    id: AchievementID,
    percent: Double,
    isCompleted: Bool,
    showsCompletionBanner: Bool
  ) {
    self.id = id
    self.percent = percent
    self.isCompleted = isCompleted
    self.showsCompletionBanner = showsCompletionBanner
  }
}

/// Lightweight value type for the local player so your app doesn't need to import GameKit in most places.
public struct Player: Equatable, Sendable {
  /// Human-readable player display name.
  public var displayName: String
  /// Stable, opaque player identifier.
  public var playerID: String

  public init(displayName: String, playerID: String) {
    self.displayName = displayName
    self.playerID = playerID
  }
}
