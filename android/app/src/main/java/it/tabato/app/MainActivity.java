package it.tabato.app;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

/**
 * Estende l'activity Capacitor di base per gestire la condivisione di un link da un'altra app
 * (es. "Condividi" dall'app Amazon) verso TabaTo, comparendo nel foglio di condivisione di
 * sistema (vedi l'intent-filter ACTION_SEND in AndroidManifest.xml). Il testo condiviso viene
 * inoltrato come query string alla pagina web "/share-target", dove il backend Spring Boot
 * (tabato-app, WishListController#shareTarget) lo interpreta come link al prodotto o descrizione
 * e lo aggiunge alla lista dei desideri dell'utente. Nessuna logica applicativa vive qui: solo
 * l'inoltro del testo condiviso, così come "server.url" in capacitor.config.ts punta sempre al
 * sito di produzione senza distribuire alcun asset web con l'app.
 */
public class MainActivity extends BridgeActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleShareIntent(getIntent());
    }

    /** Intercetta anche le condivisioni ricevute mentre l'app è già in esecuzione (launchMode="singleTask"). */
    @Override
    public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleShareIntent(intent);
    }

    private void handleShareIntent(Intent intent) {
        if (intent == null || !Intent.ACTION_SEND.equals(intent.getAction())) {
            return;
        }
        String sharedText = intent.getStringExtra(Intent.EXTRA_TEXT);
        if (sharedText == null || sharedText.trim().isEmpty()) {
            return;
        }
        String targetUrl = "https://www.tabato.it/share-target?text=" + Uri.encode(sharedText.trim());
        getBridge().getWebView().loadUrl(targetUrl);
    }
}
