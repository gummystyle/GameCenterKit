import Testing
import GameKit
@testable import GameCenterKit

@Suite("Error mapping")
struct ErrorMappingTests {
  
  @Test("GKErrorDomain to GameCenterKitError mapping")
  func testErrorMappingFromGKErrorDomainCases() {
    // notAuthenticated
    let notAuthenticatedError = NSError(domain: GKErrorDomain, code: GKError.notAuthenticated.rawValue)
    let mappedNotAuthenticated = GameCenterService.map(notAuthenticatedError)
    #expect({
      if case .some(.notAuthenticated) = (mappedNotAuthenticated as? GameCenterKitError) { return true }
      return false
    }())

    // cancelled (maps .cancelled and .userDenied to .cancelled)
    let cancelledError = NSError(domain: GKErrorDomain, code: GKError.cancelled.rawValue)
    let mappedCancelled = GameCenterService.map(cancelledError)
    #expect({
      if case .some(.cancelled) = (mappedCancelled as? GameCenterKitError) { return true }
      return false
    }())

    let userDeniedError = NSError(domain: GKErrorDomain, code: GKError.userDenied.rawValue)
    let mappedUserDenied = GameCenterService.map(userDeniedError)
    #expect({
      if case .some(.cancelled) = (mappedUserDenied as? GameCenterKitError) { return true }
      return false
    }())

    // apiNotAvailable
    let apiNotAvailableError = NSError(domain: GKErrorDomain, code: GKError.apiNotAvailable.rawValue)
    let mappedApiNotAvailable = GameCenterService.map(apiNotAvailableError)
    #expect({
      if case .some(.gameCenterUnavailable) = (mappedApiNotAvailable as? GameCenterKitError) { return true }
      return false
    }())

    // default → underlyingError
    let unknownError = NSError(domain: GKErrorDomain, code: Int(Int32.max))
    let mappedUnknown = GameCenterService.map(unknownError)
    if case let .some(.underlyingError(message)) = (mappedUnknown as? GameCenterKitError) {
      #expect(!message.isEmpty)
    } else {
      Issue.record("Expected underlyingError for unknown GKError code")
    }
  }
}
