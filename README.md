# GameCenterKit

A lightweight Swift Package that wraps Apple GameKit to make Game Center integration simple, testable, and Swift Concurrency–friendly for iOS apps.

- Authentication with the local player
- Present the Game Center dashboard (leaderboards or achievements)
- Submit scores to one or more leaderboards
- Report and load achievement progress (with basic caching)
- Control the floating Game Center Access Point
- Dependency-injection–friendly client with optional Dependencies/TCA integration

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

Optional (for `@Dependency` integration): add Point‑Free's `swift-dependencies` package and link the `Dependencies` product to any target that wants to use the dependency key:

```swift
.dependencies: [
  .package(url: "https://github.com/your-org/GameCenterKit.git", from: "0.1.0"),
  .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.4")
],
.targets: [
  .target(
    name: "YourApp",
    dependencies: [
      "GameCenterKit",
      .product(name: "Dependencies", package: "swift-dependencies")
    ]
  )
]
```

## Quick Start

### 1) Authenticate the local player (SwiftUI)

Using `PresenterReader` to obtain a presenter closure without global lookups:

```swift
import SwiftUI
import GameCenterKit

struct ContentView: View {
  @Environment(\.gameCenterClient) private var gameCenter

  var body: some View {
    PresenterReader { presenter in
      Button("Sign in to Game Center") {
        Task {
          do {
            let player = try await gameCenter.authenticate(presenter)
            print("Authenticated:", player.displayName)
          } catch {
            print("Auth failed:", error)
          }
        }
      }
    }
  }
}
```

You can also use the client/service without a presenter (falls back to a best‑effort presenter lookup):

```swift
// Client convenience (no presenter required)
let player = try await gameCenter.authenticate()

// Or call the service directly
let player2 = try await GameCenterService.shared.authenticate()
```

### 2) Present the Game Center dashboard (SwiftUI)

```swift
// With PresenterReader
PresenterReader { presenter in
  VStack {
    Button("Leaderboards") {
      Task { try await gameCenter.presentDashboard(.leaderboards(), presenter) }
    }
    Button("Specific Leaderboard") {
      Task { try await gameCenter.presentDashboard(.leaderboards(LeaderboardID("com.yourapp.leaderboard")), presenter) }
    }
    Button("Achievements") {
      Task { try await gameCenter.presentDashboard(.achievements, presenter) }
    }
  }
}
```

Or use the client convenience without a presenter:

```swift
try await gameCenter.presentDashboard(.achievements)
```

SwiftUI-only approach: embed the dashboard with a sheet using `GameCenterDashboardView`:

```swift
@State private var showDashboard = false

Button("Open Dashboard") { showDashboard = true }
.sheet(isPresented: $showDashboard) {
  GameCenterDashboardView(mode: .leaderboards())
}
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

Tip: `forceReload` defaults to `false`, so `try await gameCenter.loadAchievements()` uses the short cache window.

### 5) Show the Access Point (SwiftUI)

```swift
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

The view modifier automatically disables the access point on disappear. Prefer the modifier in SwiftUI screens, and the client/service for one‑off imperative updates.

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
  - Convenience: `authenticate()` and `presentDashboard(_:)` that locate a presenter automatically
- `GameCenterUI`
  - `GameCenterDashboardView` (SwiftUI wrapper for `GKGameCenterViewController`)
  - `.gameCenterAccessPoint(...)` view modifier
- `GameCenterModels`
  - `LeaderboardID`, `AchievementID`, `AchievementProgress`, `Player`, `DashboardMode`, `GameCenterKitError`

## Dependency Injection and Testing

- SwiftUI: access `@Environment(\.gameCenterClient)`; default is `.live`.
- For previews/tests, construct a custom client or (if using Dependencies or TCA) use the provided dependency key.

Integration via `swift-dependencies` (works with or without TCA):

```swift
import Dependencies
import GameCenterKit

struct SomeType {
  @Dependency(\.gameCenter) var gameCenter
  // use gameCenter in your logic
}
```

With TCA, you can access the same dependency key from a reducer using `@Dependency`.

For tests (plain Dependencies example):

```swift
import Dependencies

let client = GameCenterClient(
  isAuthenticated: { true },
  authenticate: { _ in Player(displayName: "Tester", playerID: "TEST") },
  presentDashboard: { _, _ in },
  submitScore: { _, _, _ in },
  reportAchievement: { _, _, _ in },
  loadAchievements: { _ in [] },
  resetAchievements: {},
  setAccessPoint: { _, _, _ in }
)

withDependencies {
  $0.gameCenter = client
} operation: {
  // run code under test that reads @Dependency(\.gameCenter)
}
```

Note: Dependency-key integration is behind `#if canImport(Dependencies)` and is available whenever the `Dependencies` product is linked (including when using TCA, which itself depends on Dependencies).

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

You can also quickly gate UI based on authentication state:

```swift
if gameCenter.isAuthenticated() {
  LeaderboardView()
} else {
  SignInPrompt()
}
```

## Setup Tips

- Enable the Game Center capability in your app target (Signing & Capabilities).
- Create leaderboards and achievements in App Store Connect; use their identifiers in code.
- Ensure the test device (or simulator) is signed into Game Center. Some flows are more reliable on a real device.

## Formatting

Use SwiftFormat locally to keep code style consistent:

`swiftformat Sources Tests --swiftversion 6`

## License

MIT — see `LICENSE` for details.
