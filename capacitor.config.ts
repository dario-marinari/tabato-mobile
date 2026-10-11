import type { CapacitorConfig } from '@capacitor/cli';

/**
 * L'app non ha una UI propria: è una WebView nativa che carica direttamente il sito TabaTo
 * (server.url), lo stesso servito ai browser desktop/mobile. Tutta la UI, la logica di business
 * e l'autenticazione restano nel backend Spring Boot del progetto "tabato-app"; questo progetto
 * aggiunge solo capacità native (condivisione di sistema, rubrica, notifiche push) tramite il
 * bridge JavaScript incluso in ogni pagina del sito (vedi tabato-app/.../js/native-bridge.js).
 *
 * "www/" contiene solo una pagina di fallback mostrata se il dispositivo è offline al primo
 * avvio: Capacitor la richiede comunque come webDir, anche quando si usa server.url.
 */
const config: CapacitorConfig = {
  appId: 'it.tabato.app',
  appName: 'TabaTo',
  webDir: 'www',
  // Colore di sfondo nativo della WebView (sotto la pagina web, visibile per una frazione di
  // secondo durante il caricamento/transizione tra pagine, dato che ogni "menu" è una navigazione
  // server-side completa e non una SPA): deve combaciare con lo sfondo del sito per evitare un
  // flash nero/bianco. Vedi anche MainViewController.swift (iOS) e MainActivity.java (Android).
  backgroundColor: '#f2fbfc',
  server: {
    // Punta sempre al sito di produzione: nessun asset web viene distribuito con l'app, quindi
    // un aggiornamento del sito è visibile agli utenti mobile senza dover ripubblicare l'app
    // (eccetto per cambi che richiedano nuovi permessi/plugin nativi).
    url: 'https://www.tabato.it',
    androidScheme: 'https',
    // Consente la navigazione the-loop verso i domini usati per share/login OAuth2 (Google/Facebook)
    // senza uscire dalla WebView dell'app; aggiornare se cambia il dominio del backend.
    allowNavigation: [
      'www.tabato.it',
      'tabato.it',
      'accounts.google.com',
      'www.facebook.com',
      'm.facebook.com'
    ]
  },
  ios: {
    contentInset: 'automatic'
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: true,
      backgroundColor: '#f2fbfc',
      androidSplashResourceName: 'splash',
      showSpinner: false
    },
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert']
    }
  }
};

export default config;
