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
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            completion(nil)
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                completion((data as? URL)?.absoluteString)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                completion(data as? String)
            }
        } else {
            completion(nil)
        }
    }

    private func openHostApp(with sharedText: String?) {
        defer {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
        guard let sharedText = sharedText,
              let encodedText = sharedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "tabato://share-target?text=\(encodedText)") else {
            return
        }
        // Le estensioni "Condividi" girano in un processo separato dall'app principale: il modo
        // supportato da Apple per rimandare il controllo all'app è extensionContext.open(_:), che
        // chiude l'estensione e chiede al sistema di aprire l'URL (schema personalizzato) nell'app.
        extensionContext?.open(url, completionHandler: nil)
    }
}
