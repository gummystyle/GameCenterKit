import SwiftUI
import UIKit

/// Reads a presenting UIViewController from SwiftUI and passes a presenter closure to content.
///
/// Useful for calling GameKit APIs that require a UIKit presenter from SwiftUI without relying
/// on global window lookups.
public struct PresenterReader<Content: View>: View {
  private let content: (@escaping @MainActor () -> UIViewController?) -> Content

  @State private var presenter: UIViewController?

  public init(
    @ViewBuilder content: @escaping (@escaping @MainActor () -> UIViewController?) -> Content
  ) {
    self.content = content
  }

  public var body: some View {
    content { presenter }
    .background(
      PresenterResolver { viewController in
        self.presenter = viewController
      }
    )
  }
}

private struct PresenterResolver: UIViewControllerRepresentable {
  let onResolve: @MainActor (UIViewController) -> Void

  func makeUIViewController(context: Context) -> UIViewController {
    UIViewController()
  }

  @MainActor
  func updateUIViewController(
    _ uiViewController: UIViewController,
    context: Context
  ) {
    onResolve(uiViewController)
  }
}
