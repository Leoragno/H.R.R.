# HRR — Heat Racers 🏁

App mobile Flutter che trasforma la guida quotidiana in un'esperienza racing:
XP, livelli, missioni, garage, crew, car spotting con riconoscimento AI.

> Vedi `ARCHITECTURE.md` per architettura completa e piano di sviluppo a fasi.

## Setup rapido

```bash
flutter pub get

# Configura ambiente
cp .env.example .env
# → compila SUPABASE_URL e SUPABASE_ANON_KEY con i valori del tuo progetto

# Applica lo schema database (richiede supabase CLI collegata al progetto)
supabase db push

# Genera codice (freezed, json_serializable, riverpod_generator, go_router)
dart run build_runner build --delete-conflicting-outputs

# Avvia
flutter run
```

## Stato del progetto

✅ Completato e verificato (`flutter analyze` pulito, `flutter test` verde,
`flutter build apk --debug` compila):
- Architettura Clean Architecture (feature-first) — cartelle per tutte le 14 feature
- Tema Material 3 dark/neon/glassmorphism (font Orbitron/Inter via `google_fonts`)
- Schema Supabase completo con RLS + economia XP/REP server-side
  (`supabase/migrations/0001_init.sql`, `0002_trip_economy_and_realtime.sql`)
- Router GoRouter con guard di autenticazione e bottom nav shell
- **Auth**: Splash → Login/Register (email + Google + Apple) → Home, Riverpod
  collegato a Supabase Auth reale
- **Home**: HUD pilota live (livello/XP/REP via Supabase Realtime, non polling),
  banner auto attiva, Start Drive
- **Garage**: CRUD auto reale, foto (image_picker + compress + Supabase
  Storage), imposta auto attiva, livello/XP auto
- **Trip Live**: tracking GPS in foreground (geolocator), HUD velocità/
  distanza/tempo, filtro jitter GPS
- **Fine Viaggio**: XP/REP calcolati **server-side** dalla RPC `complete_trip`
  (mai dal client), anti-cheat su velocità/distanza sospette, anteprima
  percorso, animazioni risultati
- Scaffold coerenti per le restanti schermate (Car Spotting, Crew, Chat,
  Classifiche, Missioni, Eventi, Impostazioni, Notifiche — pronte per Fase 3+)
- Piattaforme Android/iOS scaffoldate (`flutter create`); vedi §7 di
  `ARCHITECTURE.md` per le credenziali reali da configurare prima del run

🚧 Da sviluppare nelle prossime iterazioni (vedi `ARCHITECTURE.md` §5):
- Tracking GPS in **background** (schermo spento) — vedi `ARCHITECTURE.md` §5
  Fase 2 per l'alternativa a `background_locator_2` (rimosso, incompatibile)
- Car Spotting + pipeline riconoscimento TFLite
- Crew, chat realtime, classifiche, missioni, eventi

## Note tecniche importanti

- **Mai** scrivere direttamente su `profiles.xp/rep` — passare sempre da
  `xp_events` (vedi ARCHITECTURE.md §4) per audit trail e atomicità.
- Il layer `domain/` di ogni feature non deve MAI importare Supabase/Flutter:
  è la garanzia che i usecase restino testabili e la logica di business
  indipendente dal backend scelto.
- Rinomina il progetto (nome pacchetto Android/iOS, app id) prima della
  pubblicazione — vedi nota sul nome in `ARCHITECTURE.md`.
