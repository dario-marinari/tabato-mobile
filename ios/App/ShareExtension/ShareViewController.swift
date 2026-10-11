import UIKit
import UniformTypeIdentifiers

/// Estensione "Condividi" di sistema per iOS: compare nel foglio di condivisione quando l'utente
/// condivide un link o del testo da un'altra app (es. Amazon) o da Safari, permettendo di scegliere
/// TabaTo per aggiungere il contenuto condiviso alla propria lista dei desideri.
///
/// Non ha interfaccia propria: estrae il testo/URL condiviso e chiede al sistema di aprire l'app
/// principale tramite lo schema personalizzato "tabato://share-target?text=...", che AppDelegate
/// intercetta per caricare "https://www.tabato.it/share-target?text=..." nella WebView, replicando
/// il comportamento di MainActivity.handleShareIntent() su Android.
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        extractSharedText { [weak self] text in
            DispatchQueue.main.async {
                self?.openHostApp(with: text)
            }
        }
    }

    private func extractSharedText(completion: @escaping (String?) -> Void) {
        // Alcune app (es. Amazon) condividono più allegati, e non sempre il primo è quello utile:
        // si cerca prima un URL e, in sua assenza, un testo, fra tutti gli allegati.
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                if let url = data as? URL {
                    completion(url.absoluteString)
                } else if let text = data as? String {
                    completion(text)
                } else {
                    completion(nil)
                }
            }
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                completion(data as? String)
            }
        } else {
            completion(nil)
        }
    }

    private func openHostApp(with sharedText: String?) {
        // Esclude & + = # ecc. dal testo, altrimenti l'URL condiviso (con query string) verrebbe
        // troncato quando viene riletto come parametro "text".
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=#?/:")
        guard let sharedText = sharedText,
              let encodedText = sharedText.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "tabato://share-target?text=\(encodedText)") else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        // extensionContext.open(_:) funziona solo per i widget "Oggi", non per le estensioni
        // "Condividi": qui il sistema lo ignora in silenzio. Il metodo che funziona è risalire la
        // responder chain fino a UIApplication e chiamare open(_:options:completionHandler:).
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector), current is UIApplication {
                _ = current.perform(selector, with: url)
                break
            }
            responder = current.next
        }
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
