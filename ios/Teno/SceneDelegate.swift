import UIKit

/// Scene life-cycle host required by apps built with the iOS 26 SDK or later.
/// The Flutter engine and view controller are owned by AppDelegate; this
/// delegate only supplies the window and forwards scene-level events.
@objc(TenoSceneDelegate)
final class TenoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene,
              let app = UIApplication.shared.delegate as? AppDelegate,
              let root = app.rootController else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
        app.attach(window: window)
        app.lockForBackground()
        for context in connectionOptions.urlContexts where app.open(url: context.url) { break }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        (UIApplication.shared.delegate as? AppDelegate)?.authenticateIfNeeded()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        (UIApplication.shared.delegate as? AppDelegate)?.lockForBackground()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
        for context in URLContexts where app.open(url: context.url) { break }
    }
}
