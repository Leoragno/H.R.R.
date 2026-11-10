# HEAT — regole di design

Leggi questo file prima di scrivere o modificare qualsiasi widget.
Tutti i valori vengono da `lib/core/theme/app_theme.dart` (tipografia,
spaziatura, glow, motion), `lib/core/theme/app_colors.dart` (colore) e
`lib/core/theme/heat_shapes.dart` (forme). I componenti base sono in
`lib/core/widgets/heat/heat_widgets.dart`.
**Non scrivere mai un colore, una dimensione o una durata a mano nel codice
dei widget.**

Riferimento visivo: il prototipo `HRR App - Heat.dc.html` (handoff "HRR ·
Heat"), viewport logico 390×844.

## Direzione

Street racing notturno, *Tokyo-drift ma sobrio*: fondo inchiostro che vira
al viola, un solo accento neon, pannelli inclinati e smussati, display
condensato corsivo, qualche accento graffiti.

## Le tre regole che decidono se sembra fatto bene o fatto con un template

1. **Un solo elemento acceso per schermata.** Accento pieno + glow vanno su
   una cosa sola (la CTA, il numero protagonista, la tab attiva della nav).
   Il resto è `AppColor.surface` con bordo `AppColor.line`.
2. **L'accento è dell'utente, i semantici sono fissi.** `AppColor.accent`
   (default Corallo, scelto in Impostazioni) = tuo, attivo, primario. È
   **runtime**: non usarlo mai in un'espressione `const`.
   Semantici a significato fisso: `gold` XP/avviso/scade presto,
   `danger` errore/rivale/perso, `info` velocità/informazione,
   `success` online/completato. `night`/`day` solo per il ciclo NOTTE/GIORNO
   e HEAT. `AppMascot.*` = identità di personaggio, mai stato.
3. **Glow morbido, mai spesso.** Ombra sfocata 16–22px al 50% dell'accento
   (`ShapeDecoration.shadows`), bordi da 1px. Niente `spreadRadius`, niente
   bordi colorati spessi.

## Forme

- **Parallelogramma** (`SlantBorder`): bottoni, tab, chip, righe di lista.
  Taglio 6–20px, più grande per bottoni più grandi. `left: 0` / `right: 0`
  per tagliare un solo lato.
- **Card smussata** (`ChamferBorder`): angolo in alto a destra (e
  opzionalmente in basso a sinistra) tagliato di 10–22px.
- **Emblema esagonale** (`HexEmblemBorder`): solo per i piloti.
- **Barre di progresso** (`SkewBar`): segmentate, inclinate −30°, 4–8px.
- Niente angoli arrotondati grandi. Niente strisce diagonali sugli sfondi.

## Sfondi

`HeatBackground`: griglia di punti 16px + alone d'accento in alto a destra.
Placeholder foto: radiale `#231F2E → surface`.

## Tipografia

- **Display** — Barlow Condensed 800/900 *corsivo*, MAIUSCOLO: titoli di
  schermata 48–50px (`AppType.screenTitle`), numeri protagonisti 104–132px
  (`AppType.score`), label di sezione 13–15px spaziate 2px in `inkMuted`
  (`AppType.label`).
- **Body** — Inter 400–700, 12–15px, interlinea 1.35–1.45.
- **Graffiti** — Sedgwick Ave Display (`GraffitiText`), ruotato −4°/−8°:
  solo voti S/A/B/C, "heat", "la tua settimana". Mai per testo da leggere.
- **Giapponese** — Noto Sans JP, solo nell'intro.
- I numeri corsivi grandi vogliono 4–14px di padding a destra, altrimenti
  l'inclinazione viene tagliata.
- I numeri usano `FontFeature.tabularFigures()` (già nei ruoli display).

## Gerarchia in una schermata

Ogni schermata ha **un** protagonista e tutto il resto è supporto:

- Guida (home) → AVVIA GUIDA.
- Risultato → il punteggio FLOW.
- Gioca → gli esagoni contesi.
- Che pilota sei → il pilota attuale.

## Densità

Padding laterale 14–18px, gap tra card 4–6px, tra sezioni 22px.

## Movimento

- Tap: `scale(.97)` + opacità .85 (`HeatPressable`), `AppMotion.fast`.
- Ingresso schermata/item: `translateY(10px)` + fade, `AppMotion.enter`
  (380ms, `AppMotion.enterCurve`), item sfasati di `AppMotion.stagger`
  (`HeatEnter`). I titoli scivolano da sinistra in `AppMotion.title`.
- Bottom sheet: dal basso in `AppMotion.sheet` su scrim nero al 60%.
- Toast: in basso, bordo sinistro colorato per tipo, `AppMotion.toast`.
- Il contatore FLOW conta da 0 al valore in `AppMotion.reveal`, il glow
  cresce con lui.
- Mai `elasticOut`/`bounceOut`. Rispetta `MediaQuery.disableAnimationsOf`.

## Elemento firma

Il tracciato del percorso nel Risultato/Dettaglio guida, colorato segmento
per segmento in base alla qualità (frenate brusche evidenziate). È l'unica
cosa che può brillare parecchio oltre alla CTA.

## Copy

- Label sempre MAIUSCOLE, brevi, tecniche: `FLOW`, `ESAGONI`, `HEAT`.
- Testo dell'interfaccia in italiano, minuscolo, diretto, senza esclamativi.
- Gli stati vuoti dicono cosa fare: "nessuna guida registrata. premi AVVIA
  GUIDA per il primo FLOW."
- Il verbo di un'azione resta lo stesso in tutto il flusso.

## Guida in corso

La schermata live mostra tachimetro, mappa, avvisi e voice bar come nel
prototipo. Vincoli di sicurezza che restano:

- Niente input di testo durante la guida; solo tap grandi (≥ 56px).
- Avvisi e alert si leggono in un colpo d'occhio: una riga, numero grande.
- Lo schermo resta acceso (`wakelock`) ma con sfondo `void_` e contrasto
  basso fuori dai numeri principali.
- Il push-to-talk è un unico bottone grande; i canali si cambiano solo da
  fermi.

## Checklist prima di dichiarare finita una schermata

- [ ] Un solo elemento con accento pieno + glow
- [ ] Nessun colore, spaziatura o durata hardcoded
- [ ] `AppColor.accent` mai dentro un `const`
- [ ] Label in `AppType.label`, MAIUSCOLE
- [ ] Testata leggibile a 360px di larghezza
- [ ] Aree tappabili ≥ 48px
- [ ] Contrasto testo ≥ 4.5:1 (`inkMuted` è il minimo per testo da leggere)
