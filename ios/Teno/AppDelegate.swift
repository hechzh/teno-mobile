import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var engine: FlutterEngine?
    private var runtime: NativeRuntime?
    // Xcode 26+ links against the iOS 26 SDK, where UIKit requires the scene
    // life cycle. The Flutter host is created here but installed into the
    // window by TenoSceneDelegate once the window scene connects.
    private(set) var rootController: FlutterViewController?
    private var startupFailure: Bool = false

    override func application(_ application: UIApplication,didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey:Any]?) -> Bool {
        let flutter = FlutterEngine(name:"TenoSharedUI",project:nil,allowHeadlessExecution:true)
        flutter.run(); engine = flutter
        let controller = FlutterViewController(engine:flutter,nibName:nil,bundle:nil)
        rootController = controller
        do {
            runtime = try NativeRuntime(messenger:flutter.binaryMessenger,presenter:controller)
        }
        catch {
            startupFailure = true
        }
        return super.application(application,didFinishLaunchingWithOptions:launchOptions)
    }

    /// Installs the shared Flutter host into the scene's window.
    func attach(window: UIWindow) {
        self.window = window
        guard startupFailure, let controller = rootController else { return }
        let alert = UIAlertController(title:"Teno could not open local storage",message:"Unlock your phone and reopen Teno. Existing recordings have not been deleted.",preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"OK",style:.default))
        DispatchQueue.main.async { controller.present(alert,animated:true) }
    }

    func lockForBackground() { runtime?.personal.lockForBackground() }
    func authenticateIfNeeded() { runtime?.personal.authenticateIfNeeded() }

    @discardableResult
    func open(url: URL) -> Bool {
        guard url.isFileURL, let runtime else { return false }
        do { try runtime.personal.importer.receiveExternal(url); return true } catch { return false }
    }

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        open(url: url)
    }

    override func application(_ application: UIApplication,handleEventsForBackgroundURLSession identifier: String,completionHandler: @escaping () -> Void) {
        if identifier == UploadQueue.backgroundIdentifier { runtime?.uploads.backgroundCompletion = completionHandler }
        else { completionHandler() }
    }
}
