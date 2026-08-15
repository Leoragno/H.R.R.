# SMOOTH — regole di design

Leggi questo file prima di scrivere o modificare qualsiasi widget.
Tutti i valori vengono da `lib/core/theme/app_theme.dart` (tipografia,
spaziatura, forma, glow, motion) e `lib/core/theme/app_colors.dart` (colore).
**Non scrivere mai un colore, una dimensione o una durata a mano nel codice
dei widget.**

`app_colors.dart` estende i token base di SMOOTH (`cyan`/`magenta`/`amber` a
significato fisso) con: alias semantici `danger`/`success`/`warning`, una
rampa rarità (`rarityCommon`→`rarityLegendary`, in scala di grigio che si
accende) e `AppMascot` — una palette identità per le mascotte-rivali,
volutamente **separata** dagli accenti semantici: non ha un significato di
stato, serve solo a distinguere i personaggi, e non va mai riusata per
comunicare possesso/perdita/scadenza.

## Direzione

Notte, asfalto, strumentazione. Il riferimento non è "app con luci al neon":
è il cruscotto di un'auto ferma al buio. Quasi tutto è spento. Quello che è
acceso, è acceso per un motivo.

## Le tre regole che decidono se sembra fatto bene o fatto con un template

1. **Un solo elemento acceso per schermata.** Il neon copre meno del 10% dei
   pixel. Se stai per mettere un secondo bordo luminoso nella stessa vista,
   uno dei due va spento e diventa grigio (`AppColor.line`).
2. **Il colore ha un significato fisso.** Ciano = tuo, pulito, attivo.
   Magenta = perso, sporco, in decadimento. Ambra = scade presto.
   Mai usarli per "dare colore". Se non significa niente, resta grigio.
   (`AppMascot.*` è l'unica eccezione dichiarata: identità di personaggio,
   non stato.)
3. **Glow morbido, mai spesso.** `AppGlow.soft` / `AppGlow.edge`: bordo da 1px
   più un alone sfocato. Mai bordi colorati da 2–3px, mai `spreadRadius`,
   mai gradienti multi-hue al posto di un glow singolo.

## Tipografia

- Numeri, punteggi, label: **Rajdhani**, maiuscolo, `letterSpacing` positivo.
- Testo corrente: **Inter**.
- Nessun terzo font. Il contrasto tra questi due è l'identità.
- I numeri usano `FontFeature.tabularFigures()` così non ballano quando si animano.
- Preferisci i ruoli fissi `AppType.score/metric/label/title/body/caption`.
  `AppType.display(...)`/`AppType.text(...)` esistono solo come ponte per
  call site con dimensioni/pesi custom ereditati dal tema precedente — non
  usarli per UI nuova.

## Gerarchia in una schermata

Ogni schermata ha **un** protagonista e tutto il resto è supporto:

- Report di fine viaggio → il punteggio FLOW.
- Mappa → gli esagoni contesi, non l'interfaccia intorno.
- Garage → l'auto.
- Wanted list → le taglie.

Il protagonista prende l'accento e il glow. Il supporto è grigio su superficie.

## Densità

Padding di sezione `AppSpace.lg`, dentro le card `AppSpace.md`. Le schermate
sono spaziose, non compresse: il vuoto nero è parte dell'estetica, non spazio
sprecato. Evita di riempire ogni angolo con statistiche.

## Movimento

- Stati e tap: `AppMotion.fast`.
- Transizioni tra schermate: `AppMotion.base`.
- La rivelazione del punteggio è l'unica animazione elaborata dell'app: il
  numero conta da 0 al valore finale in `AppMotion.reveal`, il glow sale con lui.
- Curva `easeOutCubic`. Mai `elasticOut`, mai `bounceOut`.
- Rispetta `MediaQuery.disableAnimationsOf(context)`.

## Elemento firma

Il tracciato del percorso disegnato in tempo reale nel report finale, colorato
segmento per segmento in base alla qualità di guida (ciano → magenta). È l'unica
cosa nell'app che può brillare parecchio. Non ripetere questo trattamento
altrove, altrimenti smette di essere memorabile.

## Copy

- Label sempre in maiuscolo, brevi, tecniche: `FLOW`, `ESAGONI`, `TAGLIA`.
- Testo dell'interfaccia in italiano, minuscolo, diretto, senza esclamativi.
- Gli stati vuoti dicono cosa fare, non si scusano:
  "Nessun viaggio registrato. Avvia la guida per il primo FLOW."
- Gli errori dicono cosa è successo e come si risolve.
- Il verbo di un'azione resta lo stesso in tutto il flusso: se il bottone dice
  "Avvia guida", la conferma dice "Guida avviata".

## Guida in corso — non negoziabile

Durante la registrazione lo schermo resta nero e bloccato. Niente dati in
tempo reale, niente notifiche, nessuna interazione possibile. È una regola di
sicurezza prima che di design: non aggirarla per mostrare metriche live.

## Checklist prima di dichiarare finita una schermata

- [ ] Un solo elemento con accento/glow
- [ ] Nessun colore o spaziatura hardcoded
- [ ] Le label passano da `AppType.label`, in maiuscolo
- [ ] Testata leggibile a 360px di larghezza
- [ ] Aree tappabili ≥ 48px
- [ ] Contrasto del testo su fondo scuro ≥ 4.5:1 (`inkMuted` è il minimo consentito)
