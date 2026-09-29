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

Questo repository contiene solo la configurazione Capacitor (`package.json`,
`capacitor.config.ts`) e la pagina di fallback offline (`www/index.html`): **non** include le
cartelle native `android/` e `ios/`, che vanno generate localmente con la CLI Capacitor perché
richiedono i toolchain nativi (Android Studio / Xcode) non presenti in questo ambiente di
sviluppo.

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

1. Generare la chiave APNs (o certificato) nel portale Apple Developer.
2. Abilitare la capability "Push Notifications" nel target Xcode.
3. Configurare l'invio dal backend (`tabato-app`) verso APNs quando sarà implementato l'invio
   effettivo delle notifiche (oggi `PushTokenService` registra solo i token, non invia ancora
   notifiche: è il punto di partenza per quello sviluppo futuro).

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

## Struttura del repository

```
tabato-mobile/
  package.json           ← dipendenze Capacitor + plugin
  capacitor.config.ts     ← appId, appName, server.url (punta a www.tabato.it)
  tsconfig.json           ← necessario solo per capacitor.config.ts
  www/index.html          ← pagina di fallback offline (non è la UI dell'app)
  android/                ← generata con "npx cap add android" (non presente in questo commit)
  ios/                    ← generata con "npx cap add ios" (non presente in questo commit)
```
