//
//  GameCenterUI.swift
//  GameCenterKit
//
//  Created by Daniel Birkas on 2025-09-03.
//

import GameKit
import SwiftUI

/// SwiftUI wrapper for Apple's Game Center dashboard.
public struct GameCenterDashboardView: UIViewControllerRepresentable {
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

  public func updateUIViewController(
    _ viewController: GKGameCenterViewController,
    context: Context
  ) {
    // No-op: the dashboard manages its own content.
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  public final class Coordinator: NSObject, GKGameCenterControllerDelegate {
    public func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
      Task { @MainActor in
        gameCenterViewController.dismiss(animated: true)
      }
    }
  }
}

/// SwiftUI helper for showing Apple's floating Game Center Access Point.
public struct GameCenterAccessPointModifier: ViewModifier {
  public let isActive: Bool
  public let location: GKAccessPoint.Location
  public let showsHighlights: Bool

  public init(
    isActive: Bool,
    location: GKAccessPoint.Location = .topLeading,
    showsHighlights: Bool = true
  ) {
    self.isActive = isActive
    self.location = location
    self.showsHighlights = showsHighlights
  }

  public func body(content: Content) -> some View {
    content
      .task {
        GKAccessPoint.shared.location = location
        GKAccessPoint.shared.showHighlights = showsHighlights
        GKAccessPoint.shared.isActive = isActive
      }
      .onDisappear {
        GKAccessPoint.shared.isActive = false
      }
  }
}

public extension View {
  func gameCenterAccessPoint(
    isActive: Bool,
    location: GKAccessPoint.Location = .topLeading,
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
