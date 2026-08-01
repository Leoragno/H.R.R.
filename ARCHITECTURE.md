# HRR — Architettura & Piano di Sviluppo

> ⚠️ Nota sul nome: "HeatRacistRacers" contiene involontariamente "Racist".
> In questo progetto uso "HRR" / "HeatRacers" come placeholder — sostituisci
> con il nome definitivo prima della pubblicazione su Play Store.

## 1. Stack tecnico

| Layer | Scelta |
|---|---|
| Framework | Flutter 3.24+ (Dart 3.4+) |
| State management | Riverpod 2.x (+ riverpod_generator) |
| Routing | go_router (con ShellRoute per bottom nav) |
| Backend | Supabase (Postgres + PostGIS, Auth, Storage, Realtime) |
| Push/Analytics/Crash | Firebase (Messaging, Analytics, Crashlytics) |
| Mappe | flutter_map + OpenStreetMap tiles, routing via Valhalla/GraphHopper |
| Tracking GPS | geolocator (foreground); background da valutare, vedi §5 Fase 2 |
| Riconoscimento auto | TFLite (modello MobileNet fine-tuned per marca/modello) |
| Animazioni | flutter_animate, Lottie, Rive |
| Codegen | freezed + json_serializable (modelli immutabili) |

## 2. Clean Architecture — regole

Ogni feature in `lib/features/<nome>/` è divisa in 3 layer indipendenti:

```
feature/
  data/
    models/         <- DTO con freezed+json_serializable, mapping da/verso Supabase
    datasources/     <- chiamate dirette a Supabase/Firebase/HTTP (remote), o cache locale
    repositories/    <- implementazione concreta dell'interfaccia domain
  domain/
    entities/         <- oggetti di business puri, NIENTE dipendenze Flutter/Supabase
    repositories/    <- interfacce astratte (contratti)
    usecases/         <- una classe = un'azione (es. StartTripUseCase, LikeSpotUseCase)
  presentation/
    screens/          <- widget di pagina intera
    widgets/           <- componenti riusabili della feature
    providers/         <- Riverpod providers che orchestrano usecase -> stato UI
```

Regola di dipendenza: `presentation -> domain <- data`. Il domain layer non
importa mai nulla da `data` o da package Flutter/Supabase: questo rende
i usecase testabili senza mock pesanti e permette di sostituire Supabase
in futuro senza toccare la UI.

## 3. Dependency Injection

Tutto via Riverpod provider (niente get_it): ogni datasource/repository/usecase
è esposto con `@riverpod` (codegen), reso disponibile globalmente tramite
`ProviderScope` in `main.dart`. Override nei test con `ProviderContainer`.

## 4. Convenzione XP / REP / Livelli (da centralizzare in un unico Cloud Function/Edge Function)

- **XP** = esperienza guida (km percorsi, missioni, badge) → determina il **Livello**
- **REP** = reputazione community (like ricevuti su spot, missioni crew, eventi) → determina **Titolo**
- Ogni assegnazione XP/REP passa da `xp_events` (tabella append-only) — mai
  scrivere direttamente su `profiles.xp`. Un trigger Postgres (o Edge Function)
  aggiorna `profiles.xp/rep/level` in modo atomico. Questo dà audit trail e
  previene race condition su più dispositivi.
- Formula livello (esempio, da tarare): `level = floor(sqrt(xp / 100)) + 1`

### 4.1 Mission Engine (aggiunto 2026-08-01)

Event-driven, server-authoritative — stesso pattern di `complete_trip` (§4):
il client non calcola mai progressi/reward, pubblica solo fatti grezzi.

- **Bus**: `core/events/mission_event.dart` (gerarchia `MissionEvent`,
  ognuna con una `idempotencyKey` generata alla creazione) +
  `core/events/mission_event_bus.dart` (`StreamController` condiviso via
  Riverpod). Le feature pubblicano (`ref.read(missionEventBusProvider)
  .publish(TripCompleted(...))`), non chiamano mai la RPC direttamente.
- **Bridge**: `features/missions/presentation/providers/
  mission_event_bridge_provider.dart` ascolta il bus, passa ogni evento da
  `core/offline/offline_event_queue.dart` (coda `shared_preferences`,
  drenata in ordine, un solo percorso online/offline) e poi chiama la RPC
  `record_mission_event`. Idempotente per costruzione: la stessa
  `idempotencyKey` inviata due volte (retry di rete o replay offline) è un
  no-op lato server (`mission_event_log.idempotency_key unique`).
  Instanziato una volta in `main.dart` (`ref.watch(missionEventBridgeProvider)`).
- **DB**: `supabase/migrations/0003_mission_engine.sql` — ALTER su
  `missions`/`mission_progress` esistenti (0001) + nuove tabelle
  (`mission_templates`, `mission_claims`, `mission_rewards`, `season`,
  `achievements`, `user_achievements`, `crew_missions`, `crew_progress`,
  `mission_event_log`). RPC `record_mission_event` (progress engine),
  `claim_mission`/`claim_achievement`-equivalente (`evaluate_achievements`,
  auto-assegna, nessun claim manuale per gli achievement), tre generatori
  idempotenti (`generate_daily/weekly/seasonal_missions`, scheduling NON
  incluso di proposito). Le missioni segrete sono nascoste a livello di
  RLS (`missions_select_all` esclude `secret=true` finché non completate),
  non solo mascherate in UI; `mission_templates` non ha alcuna policy di
  select per i client, per non far trapelare il contenuto delle missioni
  segrete non ancora sbloccate.
- **Reward ledger**: `mission_claims` (un rigo per riscatto, audit) +
  `mission_rewards` (un rigo per reward item concesso, `reward_type` come
  stringa estendibile) — aggiungere un nuovo tipo di reward non richiede
  mai una migration.

## 5. Fasi di sviluppo consigliate

### Fase 0 — Fondamenta (fatto in questa consegna)
- [x] Struttura cartelle Clean Architecture
- [x] pubspec.yaml con dipendenze
- [x] Tema Material 3 dark/neon/glassmorphism
- [x] Schema SQL completo + RLS
- [x] Router con guard di autenticazione

### Fase 1 — Auth & Onboarding (fatto)
- [x] Splash → check sessione Supabase → redirect
- [x] Login (Google, Apple, Email) via supabase_auth
- [x] Registrazione (username univoco, creazione riga `profiles`)

### Fase 2 — Core loop di guida (fatto)
- [x] Home (HUD pilota: livello, XP bar, foto auto caricata dall'utente,
      Start Drive) — HUD live via Supabase Realtime su `profiles`
- [x] Trip Live (tracking GPS in **foreground**, HUD velocità/distanza/tempo)
- [x] Fine Viaggio (XP/REP calcolati **server-side** da `complete_trip()`,
      anteprima percorso, animazione risultati)
- [ ] Tracking in **background** (schermo spento/app minimizzata): oggi il
      tracking si ferma se l'app va in background. `background_locator_2`
      (previsto inizialmente) è stato **rimosso da pubspec.yaml**: il suo
      Gradle interno punta ad Android Gradle Plugin 4.1.3 / Kotlin 1.7.20,
      versioni che non si risolvono più su toolchain moderne (jcenter è
      dismesso) — il pacchetto è di fatto incompatibile senza patch pesanti.
      Da valutare per la prossima iterazione: `flutter_foreground_task` +
      `geolocator` (foreground service Android gestito a mano) oppure
      `flutter_background_geolocation` (a pagamento, molto più robusto).
- [ ] "Confronto con amici" a fine viaggio: rimandato a quando esisterà il
      grafo amicizie (Fase 3)

**Nota (2026-08-01):** il feature Garage (CRUD auto, `lib/features/garage/`)
è stato rimosso su richiesta — il tab in bottom nav ora porta a Missions.
La Home mostra solo uno slot foto locale (nessuna entità auto, nessun
collegamento a `carId` sui viaggi). Le tabelle `cars`/bucket `car-photos`
restano nello schema Supabase ma non sono più usate dal client.

Vedi `supabase/migrations/0002_trip_economy_and_realtime.sql` per il
trigger `apply_xp_event` + la RPC `complete_trip` (unico punto che assegna
XP/REP, con soglie anti-cheat su velocità media/distanza) e per le tabelle
aggiunte alla pubblicazione realtime.

### Fase 3 — Community
- Car Spotting (feed, upload foto, riconoscimento AI, like/dislike/commenti)
- Classifiche (globale/amici/crew, filtri settimana/mese/sempre)
- Profilo pubblico, ricerca utenti, amicizie

### Fase 4 — Crew & Social
- Crew (creazione, gestione membri, livello crew)
- Chat crew (Supabase Realtime)
- Eventi (creazione, partecipazione, mappa eventi)

### Fase 5 — Rifinitura
- [x] Mission Engine (2026-08-01) — event-driven, server-authoritative,
      vedi `supabase/migrations/0003_mission_engine.sql` e §4.1 sotto.
      Missions UI (header/tab/battle pass/overlay di completamento)
      collegata a dati reali via Riverpod, layout invariato.
- [x] Achievement permanenti (catalogo + auto-assegnazione su soglie
      `profiles.total_km/total_trips/rep/level`), screen minima raggiungibile
      da Profilo.
- [ ] Scheduling dei generatori (`generate_daily/weekly/seasonal_missions`
      esistono e sono idempotenti ma vanno richiamati manualmente/da SQL —
      pg_cron/Edge Function/GitHub Actions non ancora collegati, per scelta
      esplicita: lo scheduling resta un layer separato da decidere)
- [ ] Emettitori reali per la maggior parte dei `MissionEvent` (solo
      `TripStarted`/`TripCompleted` sono cablati end-to-end da `trip_live_
      provider.dart`; `PhotoUploaded`/`LikeReceived`/`CarSpotted`/ecc. sono
      definiti e già gestiti da `record_mission_event`, ma nessuna feature
      li pubblica ancora — Car Spotting/Crew/Eventi/Amicizie sono placeholder)
- Notifiche push (FCM) + centro notifiche in-app — `record_mission_event`/
  `claim_mission`/`evaluate_achievements` scrivono già in `notifications`
  (realtime), manca solo la consegna push (nessuna config Firebase reale)
- Impostazioni, privacy, permessi
- Performance pass (rebuild inutili, isolate per tracking GPS, cache immagini)
- Test end-to-end flussi critici, preparazione release Play Store

## 6. Prossimo passo consigliato

Fase 1 e Fase 2 sono complete e verificate (`flutter analyze` pulito,
`flutter test` verde, `flutter build apk --debug` compila). Prossimo blocco:
**Fase 3 — Car Spotting** (feed, upload foto, riconoscimento auto via
TFLite, like/dislike/commenti) seguita da Classifiche e Profilo pubblico.

## 7. Setup necessario prima di eseguire l'app

Questi pezzi sono placeholder che **vanno sostituiti con le tue credenziali
reali** prima di un run vero (l'app compila comunque senza, ma login/push/
crash reporting non funzioneranno):

- `.env` (copiato da `.env.example`): `SUPABASE_URL`/`SUPABASE_ANON_KEY` reali.
- `lib/firebase_options.dart`: rigenera con `flutterfire configure` dopo aver
  creato un progetto Firebase (serve per Messaging/Analytics/Crashlytics).
- Applica le migration in ordine: `supabase db push` (0001 poi 0002) —
  la 0002 mette `profiles` nella pubblicazione realtime, senza cui l'HUD
  pilota non riceve aggiornamenti live. Il bucket Storage `car-photos` e
  la tabella `cars` restano nello schema ma non sono più usati dal client
  dopo la rimozione del Garage (vedi nota in Fase 2).

## 8. Workflow di sviluppo e CI

Repo indipendente (`hrr_app` ha il proprio `.git`, non vive più solo
dentro un repo più ampio). Regole di branch, convenzione commit e
processo PR sono in `CONTRIBUTING.md` — leggilo prima di aprire la prima
Pull Request.

La pipeline `.github/workflows/flutter_ci.yml` gira su ogni push/PR verso
`main` ed è il gate obbligatorio prima del merge: `flutter pub get` →
`dart format --set-exit-if-changed` → `flutter analyze` →
`dart run custom_lint` (riverpod_lint) → `flutter test`. Versione Flutter
pinnata (3.41.6) per riproducibilità — se aggiorni Flutter in locale,
aggiorna anche `flutter-version` nel workflow nello stesso commit.
