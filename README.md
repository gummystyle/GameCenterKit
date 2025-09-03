# GameCenterKit

A lightweight Swift Package that wraps Apple GameKit to make Game Center integration simple, testable, and Swift Concurrency–friendly for iOS apps.

- Authentication with the local player
- Present the Game Center dashboard (leaderboards or achievements)
- Submit scores to one or more leaderboards
- Report and load achievement progress (with basic caching)
- Control the floating Game Center Access Point
- Dependency-injection–friendly client and optional TCA integration

## Requirements

- iOS 18.0+
- Swift 6.2 tools (Swift Concurrency, `Sendable`, `actor`)
- Xcode with the Game Center capability enabled for your app

## Installation (Swift Package Manager)

1) In Xcode: File → Add Packages… → enter your repository URL and add the package.

2) Or add to `Package.swift`:

```swift
.dependencies: [
  .package(url: "https://github.com/your-org/GameCenterKit.git", from: "0.1.0")
],
.targets: [
  .target(name: "YourApp", dependencies: ["GameCenterKit"])
]
```

## Quick Start

### 1) Authenticate the local player

Using the injectable `GameCenterClient` in SwiftUI:

```swift
import SwiftUI
import GameCenterKit

struct ContentView: View {
  @Environment(\.gameCenterClient) private var gameCenter

  var body: some View {
    Button("Sign in to Game Center") {
      Task {
        do {
          let presenter: @MainActor () -> UIViewController? = { topViewController() }
          let player = try await gameCenter.authenticate(presenter)
          print("Authenticated:", player.displayName)
        } catch {
          print("Auth failed:", error)
        }
      }
    }
  }
}

@MainActor
func topViewController() -> UIViewController? {
  UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .flatMap { $0.windows }
    .first(where: { $0.isKeyWindow })?
    .rootViewController
}
```

You can also call the service directly:

```swift
let player = try await GameCenterService.shared.authenticate()
```

### 2) Present the Game Center dashboard

```swift
// Leaderboards list
try await gameCenter.presentDashboard(.leaderboards(), topViewController)

// Specific leaderboard
try await gameCenter.presentDashboard(.leaderboards(LeaderboardID("com.yourapp.leaderboard")), topViewController)

// Achievements
try await gameCenter.presentDashboard(.achievements, topViewController)
```

### 3) Submit a score

```swift
try await gameCenter.submitScore(
  42,
  [LeaderboardID("com.yourapp.leaderboard")],
  0
)
```

### 4) Report and load achievements

```swift
// Report progress (0...100)
try await gameCenter.reportAchievement(
  AchievementID("first_win"),
  100,
  true
)

// Load achievements (cached for a short time)
let achievements = try await gameCenter.loadAchievements(false)
```

### 5) Show the Access Point (SwiftUI)

```swift
import GameKit

struct RootView: View {
  var body: some View {
    ContentView()
      .gameCenterAccessPoint(isActive: true, location: .topLeading, showsHighlights: true)
  }
}
```

Or via the client/service:

```swift
await gameCenter.setAccessPoint(true, .topLeading, true)
```

## API Overview

- `GameCenterService` (actor): Concurrency-safe facade over GameKit
  - `authenticate(presenter:) -> Player`
  - `presentDashboard(_:presenter:)`
  - `submit(score:to:context:)`
  - `reportAchievement(_:percentComplete:showsBanner:)`
  - `loadAchievements(forceReload:) -> [AchievementProgress]`
  - `resetAchievements()`
  - `setAccessPoint(active:location:showHighlights:)`
- `GameCenterClient` (struct): Injectable thin wrapper
  - `GameCenterClient.live` bridges to `GameCenterService.shared`
  - `EnvironmentValues.gameCenterClient` (SwiftUI)
- `GameCenterUI`
  - `GameCenterDashboardView` (SwiftUI wrapper for `GKGameCenterViewController`)
  - `.gameCenterAccessPoint(...)` view modifier
- `GameCenterModels`
  - `LeaderboardID`, `AchievementID`, `AchievementProgress`, `Player`, `DashboardMode`, `GameCenterKitError`

## Dependency Injection and Testing

- SwiftUI: access `@Environment(\.gameCenterClient)`; default is `.live`.
- For previews/tests, construct a custom client or (if using TCA) use the provided dependency key.

Composable Architecture integration (if you import TCA):

```swift
import ComposableArchitecture
import GameCenterKit

@Reducer
struct Feature {
  @Dependency(\.gameCenter) var gameCenter
  // ...
}
```

For tests:

```swift
store.dependencies.gameCenter = .init(
  isAuthenticated: { true },
  authenticate: { _ in Player(displayName: "Tester", playerID: "TEST") },
  presentDashboard: { _, _ in },
  submitScore: { _, _, _ in },
  reportAchievement: { _, _, _ in },
  loadAchievements: { _ in [] },
  resetAchievements: {},
  setAccessPoint: { _, _, _ in }
)
```

## Error Handling

`GameCenterKitError` provides readable errors such as:

- `notAuthenticated`: player not signed in
- `cancelled`: user dismissed auth flow
- `invalidPresentationContext`: no view controller to present from
- `gameCenterUnavailable`: not available or restricted on device
- `underlyingError(String)`: message from GameKit

Example:

```swift
do {
  _ = try await gameCenter.authenticate(topViewController)
} catch let error as GameCenterKitError {
  // inspect specific cases
  print(error.localizedDescription)
} catch {
  print(error)
}
```

## Setup Tips

- Enable the Game Center capability in your app target (Signing & Capabilities).
- Create leaderboards and achievements in App Store Connect; use their identifiers in code.
- Ensure the test device (or simulator) is signed into Game Center. Some flows are more reliable on a real device.

## License

MIT — see `LICENSE` for details.

