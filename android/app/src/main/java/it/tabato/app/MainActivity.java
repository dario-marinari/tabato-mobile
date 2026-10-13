package it.tabato.app;

import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.webkit.CookieManager;

import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

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
        applySystemBarInsets();
        handleShareIntent(getIntent());
    }

    @Override
    public void onResume() {
        super.onResume();
        applyDarkSystemBarIcons();
    }

    /**
     * La WebView salva i cookie su disco solo periodicamente: se l'app viene chiusa subito dopo il
     * login, il cookie "Ricordami" andrebbe perso e al riavvio verrebbe richiesto di nuovo l'accesso.
     * Il flush esplicito quando l'app esce dal primo piano lo rende persistente.
     */
    @Override
    public void onPause() {
        super.onPause();
        CookieManager.getInstance().flush();
    }

    @Override
    public void onStop() {
        super.onStop();
        CookieManager.getInstance().flush();
    }

    private void applyDarkSystemBarIcons() {
        WindowInsetsControllerCompat controller =
                WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        controller.setAppearanceLightStatusBars(true);
        controller.setAppearanceLightNavigationBars(true);
    }

    /**
     * Con targetSdk 35 Android 15 forza la modalità edge-to-edge: la WebView finirebbe sotto la barra di
     * stato e la barra di navigazione. Si applicano quindi gli inset di sistema (e della tastiera) come
     * padding del contenitore, così il sito occupa solo l'area realmente disponibile.
     */
    private void applySystemBarInsets() {
        // Sfondo chiaro dietro le barre e icone scure (ora, batteria, tasti di navigazione): senza questo
        // restano bianche e illeggibili sul fondo chiaro del sito.
        getWindow().getDecorView().setBackgroundColor(Color.parseColor("#f2fbfc"));
        applyDarkSystemBarIcons();

        View content = findViewById(android.R.id.content);
        ViewCompat.setOnApplyWindowInsetsListener(content, (view, windowInsets) -> {
            Insets bars = windowInsets.getInsets(
                    WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
            Insets ime = windowInsets.getInsets(WindowInsetsCompat.Type.ime());
            view.setPadding(bars.left, bars.top, bars.right, Math.max(bars.bottom, ime.bottom));
            return WindowInsetsCompat.CONSUMED;
        });
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
