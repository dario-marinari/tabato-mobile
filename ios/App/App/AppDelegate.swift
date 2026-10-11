import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Stesso colore di sfondo della WebView (vedi MainViewController.swift): evita un flash
        // nero anche nelle transizioni gestite a livello di finestra (es. foreground/background).
        window?.backgroundColor = UIColor(red: 0xf2 / 255.0, green: 0xfb / 255.0, blue: 0xfc / 255.0, alpha: 1.0)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Lo Share Extension (foglio "Condividi" di sistema) rimanda il controllo all'app aprendo
        // lo schema personalizzato "tabato://share-target?text=...": lo intercettiamo qui e carichiamo
        // direttamente la pagina corrispondente nella WebView di Capacitor, replicando il comportamento
        // di MainActivity.handleShareIntent() su Android.
        if url.scheme == "tabato", url.host == "share-target" {
            handleShareTarget(url)
            return true
        }
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    private func handleShareTarget(_ url: URL, attempt: Int = 0) {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=#?/:")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let sharedText = components.queryItems?.first(where: { $0.name == "text" })?.value,
              let encodedText = sharedText.addingPercentEncoding(withAllowedCharacters: allowed),
              let targetURL = URL(string: "https://www.tabato.it/share-target?text=\(encodedText)") else {
            return
        }
        if let bridgeViewController = window?.rootViewController as? CAPBridgeViewController,
           let webView = bridgeViewController.webView {
            webView.load(URLRequest(url: targetURL))
        } else if attempt < 10 {
            // Avvio a freddo: la WebView di Capacitor potrebbe non essere ancora pronta.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handleShareTarget(url, attempt: attempt + 1)
            }
        }
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}
