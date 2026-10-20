import SwiftUI

@main
struct CabinViewApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup { LaunchView() }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        guard session.role.rawValue == "CPTemplateApplicationSceneSessionRoleApplication" else {
            return UISceneConfiguration(name: nil, sessionRole: session.role)
        }
        return UISceneConfiguration(name: "CabinViewCarPlay", sessionRole: session.role)
    }
}
