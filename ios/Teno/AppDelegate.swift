import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var engine: FlutterEngine?
    private var runtime: NativeRuntime?
    override func application(_ application: UIApplication,didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey:Any]?) -> Bool {
        let flutter = FlutterEngine(name:"TenoSharedUI",project:nil,allowHeadlessExecution:true)
        flutter.run(); engine = flutter
        let controller = FlutterViewController(engine:flutter,nibName:nil,bundle:nil)
        window = UIWindow(frame:UIScreen.main.bounds); window?.rootViewController = controller; window?.makeKeyAndVisible()
        do { runtime = try NativeRuntime(messenger:flutter.binaryMessenger,presenter:controller) }
        catch {
            let alert = UIAlertController(title:"Teno could not open local storage",message:"Unlock your phone and reopen Teno. Existing recordings have not been deleted.",preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:"OK",style:.default))
            DispatchQueue.main.async { controller.present(alert,animated:true) }
        }
        return super.application(application,didFinishLaunchingWithOptions:launchOptions)
    }
    override func application(_ application: UIApplication,handleEventsForBackgroundURLSession identifier: String,completionHandler: @escaping () -> Void) {
        if identifier == "com.teno.app.uploads" { runtime?.uploads.backgroundCompletion = completionHandler }
        else { completionHandler() }
    }
}
