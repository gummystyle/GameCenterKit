//
//  GameCenterUI.swift
//  GameCenterKit
//
//  Created by Daniel Birkas on 2025-09-03.
//

import GameKit
import SwiftUI

/// SwiftUI wrapper for Apple's Game Center dashboard.
///
/// Use from SwiftUI with `.sheet`/`.fullScreenCover` to present leaderboards
/// or achievements without directly interacting with UIKit.
public struct GameCenterDashboardView: UIViewControllerRepresentable {
  /// The dashboard content to present.
  public let mode: DashboardMode

  public init(mode: DashboardMode) {
    self.mode = mode
  }

  public func makeUIViewController(context: Context) -> GKGameCenterViewController {
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

    viewController.gameCenterDelegate = context.coordinator
    return viewController
  }

  /// No-op: the dashboard manages its own content.
  public func updateUIViewController(
    _ viewController: GKGameCenterViewController,
    context: Context
  ) {}

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// Delegate to dismiss the Game Center controller when finished.
  public final class Coordinator: NSObject, GKGameCenterControllerDelegate {
    public func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
      Task { @MainActor in
        gameCenterViewController.dismiss(animated: true)
      }
    }
  }
}

/// SwiftUI helper for showing Apple's floating Game Center Access Point.
///
/// Applies a task to configure the shared ``GKAccessPoint`` and disables the
/// access point automatically when the modified view disappears.
public struct GameCenterAccessPointModifier: ViewModifier {
  /// Whether the access point is visible.
  public let isActive: Bool
  /// Screen corner for the access point.
  public let location: AccessPointLocation
  /// Whether to show highlight content in the access point.
  public let showsHighlights: Bool

  public init(
    isActive: Bool,
    location: AccessPointLocation = .topLeading,
    showsHighlights: Bool = true
  ) {
    self.isActive = isActive
    self.location = location
    self.showsHighlights = showsHighlights
  }

  public func body(content: Content) -> some View {
    content
      .task {
        GKAccessPoint.shared.location = map(location)
        GKAccessPoint.shared.showHighlights = showsHighlights
        GKAccessPoint.shared.isActive = isActive
      }
      .onDisappear {
        GKAccessPoint.shared.isActive = false
      }
  }
}

public extension View {
  /// Configures the floating Game Center Access Point for this view hierarchy.
  ///
  /// - Parameters:
  ///   - isActive: Whether the access point is visible.
  ///   - location: Screen corner for the access point.
  ///   - showsHighlights: Whether to show highlight content in the access point.
  func gameCenterAccessPoint(
    isActive: Bool,
    location: AccessPointLocation = .topLeading,
    showsHighlights: Bool = true
  ) -> some View {
    modifier(
      GameCenterAccessPointModifier(
        isActive: isActive,
        location: location,
        showsHighlights: showsHighlights
      )
    )
  }
}

// MARK: - Private helpers

private func map(_ location: AccessPointLocation) -> GKAccessPoint.Location {
  switch location {
  case .topLeading: return .topLeading
  case .topTrailing: return .topTrailing
  case .bottomLeading: return .bottomLeading
  case .bottomTrailing: return .bottomTrailing
  }
}
