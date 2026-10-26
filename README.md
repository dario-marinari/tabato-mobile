# TabaTo Mobile

App Android/iOS di [TabaTo](https://www.tabato.it), realizzata come **WebView wrapper con
Capacitor**: non contiene una UI propria, carica direttamente il sito di produzione
(`https://www.tabato.it`, vedi `capacitor.config.ts`) e aggiunge solo le capacità native che il
web non può offrire:

- **Condivisione nativa** (foglio di sistema Android/iOS), che a differenza dei link web
  `sharer.php` / `wa.me` include anche le voci "Aggiungi al tuo Stato" (WhatsApp) e "Aggiungi
  alla tua Storia" (Facebook/Instagram).
- **Accesso alla rubrica del telefono**, per la funzione "trova amici" (confronto via hash,
  nessuna email in chiaro lascia il dispositivo).
- **Notifiche push** (FCM su Android, APNs su iOS).
- **Scansione QR/codici a barre tramite fotocamera nativa** nel form "Aggiungi un desiderio": un
  QR con un link riusa l'anteprima prodotto già esistente, un codice a barre (EAN/UPC) riusa la
  ricerca prodotti online già esistente — entrambe le funzionalità web restano invariate, lo
  scanner si limita a compilare il campo descrizione come farebbe l'utente digitando o incollando
  a mano (vedi `native-bridge.js`, funzione `wireBarcodeScan`).

Tutta la UI, l'autenticazione e la logica di business restano nel backend Spring Boot del
progetto **`tabato-app`** (repository separata). Il ponte JavaScript che questa app usa per
dialogare con le pagine web è già incluso lì:
`tabato-app/src/main/resources/static/js/native-bridge.js`.

## Perché questo approccio (e non un'app nativa/Flutter)

`tabato-app` oggi espone solo pagine server-rendered (Thymeleaf) con sessione Spring Security,
non un'API REST completa. Il wrapper Capacitor riusa il 100% di quel backend senza modifiche
strutturali: bastano due endpoint mirati (`/api/contacts/match`, `/api/push-tokens`), già
aggiunti lato server. Un'app nativa/Flutter richiederebbe invece un intero layer REST + gestione
token separata dalla sessione web: non giustificato per l'attuale dimensione del prodotto.

## Prerequisiti locali (da fare su una macchina con Node.js)

Le cartelle native `android/` e `ios/` sono generate con la CLI Capacitor (`npx cap add
<platform>`) e **sono committate** in questo repository: la generazione del progetto Xcode/
Android Studio non richiede i rispettivi IDE installati (solo `cap add`/`cap sync` girano ovunque
ci sia Node.js), ma build, firma e pubblicazione sì — per iOS questo avviene via CI cloud (vedi
sezione "Pubblicazione su App Store" più sotto), non serve un Mac fisico.

```powershell
# 1. Installa le dipendenze
npm install

# 2. Genera i progetti nativi (una tantum, poi vanno committati)
npx cap add android   # richiede Android Studio + SDK
npx cap add ios       # richiede Xcode (solo su macOS)

# 3. Ad ogni modifica di capacitor.config.ts o dei plugin
npx cap sync

# 4. Apri i progetti nativi per build/firma/pubblicazione
npx cap open android
npx cap open ios
```

## Permessi nativi da aggiungere dopo `cap add`

I file manifest sono generati dalla CLI e vanno personalizzati a mano una volta, perché Capacitor
non conosce a priori quali plugin richiedono quali permessi runtime.

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Inoltre, dentro il tag `<application>` (richiesto da `@capacitor-mlkit/barcode-scanning` per
scaricare il modello di riconoscimento ML Kit al primo utilizzo):

```xml
<meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="barcode_ui" />
```

`@capacitor-mlkit/barcode-scanning` richiede inoltre `minSdkVersion = 23` (Capacitor 6 genera di
default 22): in `android/variables.gradle` aggiornare (o aggiungere, se non già presente) la voce:

```gradle
ext {
    minSdkVersion = 23
    // ... altre voci già generate da "cap add android" restano invariate
}
```

### iOS — `ios/App/App/Info.plist`

```xml
<key>NSContactsUsageDescription</key>
<string>TabaTo usa la rubrica solo per suggerirti quali amici sono già iscritti, tramite un confronto sicuro basato su hash: nessuna email dei tuoi contatti viene inviata in chiaro o salvata.</string>
<key>NSCameraUsageDescription</key>
<string>TabaTo usa la fotocamera per inquadrare i QR code delle liste dei desideri e per scansionare QR/codici a barre dei prodotti quando aggiungi un desiderio.</string>
```

> Il testo esatto delle stringhe `NS*UsageDescription` è quello mostrato all'utente nel dialog di
> permesso di iOS ed è anche verificato in fase di App Store review: deve descrivere fedelmente
> l'uso reale (vedi sezione Privacy sotto).

> `@capacitor-mlkit/barcode-scanning` richiede un deployment target iOS minimo 15.5: verificare
> `platform :ios, '15.5'` (o superiore) in `ios/App/Podfile` dopo `cap add ios`.

### Firebase Cloud Messaging (push Android)

1. Creare un progetto Firebase, aggiungere l'app Android con `applicationId = it.tabato.app`.
2. Scaricare `google-services.json` e copiarlo in `android/app/`.
3. Seguire la guida di setup di `@capacitor/push-notifications` per Android (plugin Google
   Services Gradle, già gestito da `cap add android` + `cap sync` per la maggior parte).

### Apple Push Notification service (push iOS)

1. Generare la chiave APNs (Apple Developer → Keys, Sandbox & Production, Team Scoped) e
   caricarla in Firebase → Cloud Messaging → app iOS (righe sviluppo e produzione), con Key ID
   e Team ID. L'App ID `it.tabato.app` deve avere "Push Notifications" abilitato.
2. Senza Xcode, la configurazione nativa è già nel progetto (modificata a mano):
   - `ios/App/App/GoogleService-Info.plist` (referenziato in `project.pbxproj`);
   - `ios/App/App/App.entitlements` con `aps-environment`, impostato in `CODE_SIGN_ENTITLEMENTS`;
   - `UIBackgroundModes` → `remote-notification` in `Info.plist`;
   - `pod 'FirebaseMessaging'` nel `Podfile`, **dentro `target 'App'`** e non in `capacitor_pods`
     (`npx cap sync ios` riscrive quel blocco e rimuoverebbe il pod: errore "unable to resolve
     module dependency: 'FirebaseCore'"); Codemagic esegue poi `pod install`;
   - `AppDelegate.swift`: `FirebaseApp.configure()` e inoltro al plugin del token **FCM** (il
     plugin di default restituirebbe il token APNs grezzo, inutilizzabile via FCM).
3. L'invio è implementato nel backend (`FcmPushSender` in `tabato-app`, attivo con
   `APP_PUSH_FCM_CREDENTIALS_PATH`); vedi il README di `tabato-app`, sezione "Segui lista e
   notifiche push".

## Come funziona il bridge lato web

Le pagine di `tabato-app` includono sempre
`tabato-app/src/main/resources/static/js/native-bridge.js` (vedi `fragments.html`), che:

1. Rileva `window.Capacitor` (presente solo dentro questa app, mai nel browser normale).
2. Sostituisce i pulsanti di condivisione web con il foglio di condivisione nativo
   (`data-native-share` in `list-manage.html`).
3. Espone `window.tabatoFindFriendsFromContacts()` per la ricerca amici via rubrica.
4. Registra il token push al primo avvio, se l'utente è autenticato.

Nessuna pagina HTML/CSS di questa app: tutta la UI resta quella servita da `tabato-app`, quindi
un aggiornamento del sito è visibile agli utenti mobile senza necessità di ripubblicare l'app,
**tranne** quando cambia qualcosa che riguarda i plugin nativi stessi (nuovo permesso, nuovo
plugin): in quel caso serve una nuova build/submission.

## Privacy — checklist prima della pubblicazione sugli store

- [ ] Aggiornare `privacy.html` in `tabato-app` con una sezione dedicata su: accesso rubrica,
      finalità (trova amici), hashing SHA-256 lato client, nessuna condivisione con terzi.
- [ ] Compilare il questionario "App Privacy" di App Store Connect e la sezione "Data safety" di
      Google Play Console coerentemente con quanto sopra.
- [ ] Verificare che nessun contatto in chiaro venga mai loggato lato client o server (solo hash).

## Pubblicazione su App Store (senza Mac fisico)

Non possedendo un Mac, la build/firma/upload iOS viene delegata a **Codemagic** (CI cloud con
runner macOS), configurato in `codemagic.yaml`. Procedura una tantum:

1. **Apple Developer Program** (99 $/anno): iscriversi su https://developer.apple.com/programs/.
2. **Repo privato** su GitHub/GitLab (solo tu come collaboratore) contenente questo progetto,
   incluse le cartelle `android/` e `ios/` già generate — collegarlo a Codemagic
   (https://codemagic.io), piano gratuito (500 min/mese di build macOS).
3. In App Store Connect (https://appstoreconnect.apple.com):
   - Creare l'app (bundle ID `it.tabato.app`, nome "TabaTo").
   - Generare una **API Key** (Users and Access > Integrations > App Store Connect API) con ruolo
     "App Manager".
4. In Codemagic (Team settings > Integrations > App Store Connect): incollare la API Key,
   nominando l'integrazione `tabato_app_store_connect` (nome già referenziato in
   `codemagic.yaml`).
5. Aggiornare in `codemagic.yaml` il valore `APP_STORE_APPLE_ID` con l'Apple ID numerico
   dell'app (visibile in App Store Connect, sezione "App Information").
6. Lanciare la build creando un tag `ios-<versione>` (es. `ios-1.0.0`): Codemagic compila,
   firma automaticamente (certificati/profili gestiti dall'integrazione) e carica la build su
   **TestFlight** (`submit_to_app_store: false` di default — sottomissione a App Store manuale o
   impostando `submit_to_app_store: true` quando pronti).

Icona App Store e splash screen sono già generate in `ios/App/App/Assets.xcassets/` a partire dal
master `resources/icon.png` (1024×1024), tramite `npx capacitor-assets generate --ios`: da
rilanciare solo se l'icona master cambia.

Gli screenshot per App Store Connect (6.9", 1320×2868 px) sono in `store-assets/ios-screenshots/`,
catturati automaticamente dalle pagine pubbliche del sito (home + lista di esempio) con
Playwright — nessun login necessario. Per rigenerarli dopo modifiche grafiche al sito:
`store-assets/ios-screenshots/generate-screenshots.js` (vedi istruzioni in testa al file).

Asset ancora da preparare prima della review pubblica: descrizione/parole chiave, categoria, età
consigliata e la checklist privacy già elencata sopra. Vedi anche le linee guida Apple 4.2/4.2.3
(minima funzionalità/"repackaged website"): le funzioni native di questa app (condivisione,
rubrica, push, scanner fotocamera) vanno evidenziate nelle note al reviewer per giustificare
l'approvazione.

## Struttura del repository

```
tabato-mobile/
  package.json           ← dipendenze Capacitor + plugin
  capacitor.config.ts     ← appId, appName, server.url (punta a www.tabato.it)
  tsconfig.json           ← necessario solo per capacitor.config.ts
  www/index.html          ← pagina di fallback offline (non è la UI dell'app)
  android/                ← generata con "npx cap add android"
  ios/                    ← generata con "npx cap add ios"
  codemagic.yaml          ← pipeline CI per build/firma/upload iOS su App Store Connect
```
