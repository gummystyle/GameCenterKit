# AGENTS: Contributing with AI Agents

This document is for AI coding agents (and humans) working in this repository. It explains the project layout, concurrency and UI rules, extension patterns, testing, and Do/Don’t guidance to keep changes safe and consistent.

## Purpose

GameCenterKit is a lightweight Swift package that wraps Apple GameKit to make Game Center integration simple, testable, and Swift Concurrency–friendly. It provides:

- A concurrency-safe `GameCenterService` actor over GameKit
- An injectable `GameCenterClient` facade for apps, previews, and tests
- SwiftUI helpers for presenting Game Center UI and the Access Point
- Optional Composable Architecture (TCA) integration behind `#if canImport(ComposableArchitecture)`

Targets: iOS 18+, Swift tools 6.2.

## Architecture Overview

- `GameCenterService` (actor)
  - Owns state (e.g., achievement cache) and talks to GameKit.
  - Performs callback→async bridges with continuations.
  - Presents Game Center UI via main-actor contexts only where needed.

- `GameCenterClient` (struct)
  - Thin, `Sendable` facade exposing closure properties for each operation.
  - `GameCenterClient.live` forwards to `GameCenterService.shared`.
  - `preview` and TCA `testValue` provide no-op/mock behavior.

- `GameCenterUI`
  - SwiftUI wrappers for the Game Center dashboard and Access Point.

- `PresenterReader`
  - Safe way to obtain a UIKit presenter from SwiftUI without global lookups.

- Models
  - Lightweight, `Sendable` value types and identifiers (`LeaderboardID`, `AchievementID`, `AchievementProgress`, `Player`) plus `GameCenterKitError` and `DashboardMode`.

## Concurrency & Actors

- Actor isolation:
  - Service methods that mutate service state or perform non-UI work remain on the service actor.
  - UI-affecting methods should be explicitly annotated `@MainActor` (see `setAccessPoint`).

- Main actor rules:
  - If a method is annotated `@MainActor`, just call it with `await` from non‑main contexts; Swift hops to the main actor for you. Do not additionally wrap in `MainActor.run {}`.
  - Use `try await MainActor.run { ... }` only when you need a short main-actor block inside a non-main function that is not itself `@MainActor`.

- Continuations:
  - Use `withCheckedThrowingContinuation` (or non-throwing variant) to bridge old GameKit callbacks.
  - Always resume exactly once on all code paths; map errors through `GameCenterService.map(_:)`.

- Sendable:
  - Public value types and closure properties should be `Sendable`.
  - Keep `GameCenterClient` operations annotated `@Sendable`.

## UI & Presentation

- UIKit interactions must run on the main actor.
  - `presentDashboard` uses `try await MainActor.run { ... }` to present a `GKGameCenterViewController`.
  - `setAccessPoint` is `@MainActor` to mutate `GKAccessPoint.shared`.

- Presenter sourcing:
  - Prefer `PresenterReader` to obtain a `UIViewController` from SwiftUI.
  - If a presenter is not supplied, the service may fall back to `topViewController()` best-effort lookup (main actor).

## Error Handling

- Use `GameCenterKitError` for readable, domain-specific errors.
- Bridge GameKit errors with `GameCenterService.map(_:)`.
- Don’t surface raw `NSError` messages directly from public APIs unless wrapped as `.underlyingError(String)`.

## Extending the API (Step-by-step)

When adding a new capability (e.g., challenges, saved games), follow this sequence:

1) Add a service method on `GameCenterService`:
   - Keep it on the service actor unless it must be `@MainActor`.
   - Bridge GameKit callbacks with continuations and map errors.
   - Update caches or internal state only within the actor.

2) Thread through the client:
   - Add a closure property to `GameCenterClient` with `@Sendable` and appropriate `async/throws` signature.
   - Update the initializer to accept the new closure.
   - Update `GameCenterClient.live` to forward to the new service method.
   - Update `preview` and TCA `testValue` to provide harmless defaults/no-ops.

3) SwiftUI helpers (optional):
   - If UI is involved, consider a `UIViewControllerRepresentable` wrapper.
   - Use a coordinator that dismisses the Game Center controller via main actor.

4) Documentation:
   - Add doc comments to the new API and, if warranted, update `Sources/GameCenterKit/GameCenterKit.docc/GameCenterKit.md` and the README’s “API Overview”.

5) Tests:
   - Prefer tests against the client and pure mapping logic.
   - Use the `Testing` package (`@Test`) rather than XCTest.

## Very Important: Naming (No Abbreviations)

- Do not use abbreviated variable, function, or type names anywhere in the codebase (production code, tests, examples, or docs). Prefer clear, descriptive names like `apiNotAvailableError` over `apiNA`, and `achievement` over `gk`. Readability and intent trump brevity.
- Exceptions: widely accepted acronyms (e.g., `URL`, `ID`, `HTTP`) are allowed; keep casing consistent with existing style (for example, `playerID`).

## Testing & Commands

- Build: `swift build`
- Tests: `swift test`
- Minimum iOS: 18.0 (some runtime flows require device/Game Center login).

Testing tips:

- Mock via `GameCenterClient` in SwiftUI or TCA environments.
- For service logic that is mostly bridging and mapping, test the mapping helpers and client wiring.
- Do not attempt to UI-test GameKit controllers here; rely on integration testing in the app.

### Swift Testing References

- See `Tests/swift-testing-playbook.md` for style, structure, and fixtures guidance used in this repo.
- See `Tests/swift-testing-api.md` for API reference of the Swift Testing framework available in Xcode 16+.

When writing tests in this repository:

- Prefer `@Test` functions with clear, descriptive names and focused assertions.
- Group related tests in separate files by topic (e.g., error mapping, client wiring).
- Use `@testable import GameCenterKit` to access internal helpers like mapping functions.
- Avoid invoking real GameKit network/UI flows; stick to pure mappings and preview/test clients.

### Test Organization

- Organize tests by subject, not in a single catch‑all file. Create multiple files per suite and name files after what they test (for example: `ErrorMappingTests.swift`, `AchievementMappingTests.swift`, `PreviewClientTests.swift`). Keep each suite focused and colocated with related assertions.
- Name test functions starting with `test`, followed by clear, descriptive names of the behavior under test (for example: `testErrorMappingFromGKErrorDomainCases`, `testMapsGKAchievementToAchievementProgress`).

## Style & Formatting

- Follow existing naming and doc-comment style.
- Prefer minimal, focused changes; do not reformat unrelated files.
- If `swiftformat` is installed locally, you may run it before finishing. The repo depends on SwiftFormat but does not enforce CI formatting; don’t add format tooling or configs without discussion.

## Conditional Dependencies (TCA)

- All TCA-related code is behind `#if canImport(ComposableArchitecture)`.
- Keep these sections compiling when TCA is present, and invisible otherwise.
- If you add new client properties, mirror them in the TCA dependency key `testValue` and `previewValue`.

## Do / Don’t Checklist

Do:

- Keep UI on the main actor; use `@MainActor` or `MainActor.run` as appropriate.
- Use continuations to bridge GameKit callbacks; resume once; map errors.
- Maintain `Sendable` constraints across public API and closures.
- Update `live`, `preview`, and TCA `testValue` when adding client operations.
- Add concise doc comments for all public APIs.

Don’t:

- Don’t call `MainActor.run {}` around a method already marked `@MainActor`; an `await` is sufficient.
- Don’t leak GameKit types through public APIs when a lightweight model exists.
- Don’t mutate service state off the service actor.
- Don’t introduce global singletons beyond the existing `GameCenterService.shared`.
- Don’t change package names, targets, or platforms without coordination.

## Quick Reference: Common Patterns

Bridge GameKit callback to async:

```swift
try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
  GKAchievement.resetAchievements { error in
    if let error { continuation.resume(throwing: Self.map(error)) }
    else { continuation.resume() }
  }
}
```

Present UI from a non-main context:

```swift
try await MainActor.run {
  let presenter = presenter?() ?? Self.topViewController()
  guard let presenter else { throw GameCenterKitError.invalidPresentationContext }
  presenter.present(viewController, animated: true)
}
```

Call a `@MainActor` API from anywhere:

```swift
await service.setAccessPoint(active: true, location: .topLeading, showHighlights: true)
// No need for MainActor.run here — the method is @MainActor.
```

Thread through the client:

```swift
public struct GameCenterClient: Sendable {
  public var newOperation: @Sendable () async throws -> Void
  // ...initializer updated accordingly...
  public static let live: GameCenterClient = {
    let service = GameCenterService.shared
    return GameCenterClient(
      // ...
      newOperation: { try await service.newOperation() }
    )
  }()
}
```

---

If something you need isn’t covered here, prefer following existing patterns in the codebase. Keep changes minimal, actor-safe, and UI on the main actor. 
