//
//  GameCenterModels.swift
//  GameCenterKit
//
//  Created by Daniel Birkas on 2025-09-03.
//

import Foundation
import GameKit

public struct LeaderboardID: RawRepresentable, Hashable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct AchievementID: RawRepresentable, Hashable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum GameCenterKitError: LocalizedError, Sendable {
  case notAuthenticated
  case cancelled
  case invalidPresentationContext
  case gameCenterUnavailable
  case underlyingError(String)

  public var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "Game Center player is not authenticated."
    case .cancelled:
      return "Game Center authentication was cancelled."
    case .invalidPresentationContext:
      return "No view controller available to present Game Center UI."
    case .gameCenterUnavailable:
      return "Game Center is not available on this device or is restricted."
    case let .underlyingError(message):
      return message
    }
  }
}

public enum DashboardMode: Sendable, Equatable {
  case leaderboards(LeaderboardID? = nil)
  case achievements
}

/// Lightweight value type for Achievements so your app doesn't need to import GameKit in most places.
public struct AchievementProgress: Equatable, Sendable {
  public var id: AchievementID
  public var percent: Double
  public var isCompleted: Bool
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

/// Lightweight value type for the Player so your app doesn't need to import GameKit in most places.
public struct Player: Equatable, Sendable {
  public var displayName: String
  public var playerID: String

  public init(displayName: String, playerID: String) {
    self.displayName = displayName
    self.playerID = playerID
  }
}
