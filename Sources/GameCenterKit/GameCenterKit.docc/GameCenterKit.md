# ``GameCenterKit``

GameCenterKit is a lightweight Swift package that wraps Apple GameKit to make
Game Center integration simple, testable, and Swift Concurrency–friendly for iOS apps.

## Overview

Use ``GameCenterClient`` in application code for dependency injection and testing,
and ``GameCenterService`` as the underlying actor that talks to GameKit. For UI
presentation in SwiftUI, use ``GameCenterDashboardView`` and the ``View/gameCenterAccessPoint(isActive:location:showsHighlights:)`` modifier.

### Key Features

- Authenticate the local player
- Present the dashboard (leaderboards or achievements)
- Submit scores and report achievement progress
- Load/reset achievements with simple caching
- Control the floating Game Center Access Point

## Topics

### Core Service

- ``GameCenterService``
- ``Player``

### Identifiers and Models

- ``LeaderboardID``
- ``AchievementID``
- ``AchievementProgress``
- ``DashboardMode``
- ``GameCenterKitError``

### Client and Integration

- ``GameCenterClient``
- ``EnvironmentValues/gameCenterClient``

### SwiftUI

- ``GameCenterDashboardView``
- ``View/gameCenterAccessPoint(isActive:location:showsHighlights:)``

### Access Point Location

- ``AccessPointLocation``
