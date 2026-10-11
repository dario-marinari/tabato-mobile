import UIKit
import Capacitor

/// Sottoclasse di CAPBridgeViewController usata da Main.storyboard al posto della classe
/// standard "Capacitor.CAPBridgeViewController", al solo scopo di forzare lo sfondo nativo
/// della WKWebView.
///
/// Perché serve: l'app non ha una SPA, ogni "menu" è una navigazione server-side completa
/// (pagine Thymeleaf renderizzate da tabato-app). Durante lo scaricamento/rendering della
/// nuova pagina, WKWebView mostra per una frazione di secondo il proprio sfondo nativo, che
/// di default è nero/trasparente: da qui il flash nero notato navigando tra i menu.
/// Impostando `isOpaque = false` + un backgroundColor esplicito sia sulla webView che sulla
/// sua scrollView, quel breve frame intermedio mostra il colore del sito (#f2fbfc) invece del
/// nero, rendendo la transizione impercettibile. Stesso colore usato in:
/// - capacitor.config.ts (chiave "backgroundColor", radice)
/// - MainActivity.java (Android, applySystemBarInsets)
class MainViewController: CAPBridgeViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        applyBackgroundColor()
    }

    override func capacitorDidLoad() {
        super.capacitorDidLoad()
        applyBackgroundColor()
    }

    private func applyBackgroundColor() {
        let brandColor = UIColor(red: 0xf2 / 255.0, green: 0xfb / 255.0, blue: 0xfc / 255.0, alpha: 1.0)
        view.backgroundColor = brandColor
        webView?.isOpaque = false
        webView?.backgroundColor = brandColor
        webView?.scrollView.backgroundColor = brandColor
    }
}
