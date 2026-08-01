# Contribuire a HRR

Regole minime per lavorare su questo repo in team. Se qualcosa qui sotto
non è chiaro o non riflette più come lavoriamo davvero, aggiorna questo
file nella stessa PR che introduce il cambiamento.

## Branch

- `main` è protetto: nessun push diretto, solo merge di Pull Request con
  CI verde (vedi sotto).
- Ogni lavoro parte da un branch dedicato, nominato:
  - `feature/<breve-descrizione>` — nuova funzionalità
  - `fix/<breve-descrizione>` — bug fix
  - `refactor/<breve-descrizione>` — refactor senza cambio di comportamento
  - `chore/<breve-descrizione>` — infrastruttura, dipendenze, CI, docs
- Un branch = un argomento. Non mischiare un fix con un refactor non
  correlato nello stesso branch/PR: rende il review inutilmente difficile.

## Convenzione commit

Messaggi in stile [Conventional Commits](https://www.conventionalcommits.org/),
imperativo, in italiano o inglese (coerente col resto del file toccato):

```
<tipo>(<scope opzionale>): <descrizione breve>

[corpo opzionale — il perché, non il cosa]
```

Tipi ammessi: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`
(solo formattazione), `perf`.

Esempi:
```
feat(missions): aggiungi generatore missioni stagionali
fix(trip): correggi calcolo velocità media su GPS jitter
refactor(auth): estrai supabaseClientProvider in core/network
chore(ci): pinna versione Flutter nella pipeline
```

Ogni commit deve lasciare il progetto in uno stato che compila e passa i
test — evita commit "WIP" su `main`; su un branch di lavoro va bene,
ma va squashato/pulito prima del merge.

## Prima di aprire una PR

Esegui in locale (sono esattamente gli step della CI, vedi
`.github/workflows/flutter_ci.yml`):

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run custom_lint
flutter test
```

Se `dart format` segnala differenze, applica `dart format .` e ricommitta
— non aggirare mai il check con `--no-verify` o simili.

Se hai toccato una entità/provider/modello annotato con `@riverpod`,
`@freezed` o `@JsonSerializable`, rigenera il codice e **committa i file
generati** (`*.g.dart`): sono tracciati nel repo (non in `.gitignore`) di
proposito, così la CI non deve rieseguire `build_runner`.

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Processo Pull Request

1. Apri la PR verso `main` con una descrizione di **cosa** cambia e
   **perché** (il "cosa" spesso si legge dal diff, il "perché" no).
2. La pipeline **Flutter CI** deve essere verde — è un requisito
   bloccante, non un suggerimento. Una PR con CI rossa non va in review
   finché non è verde.
3. Serve almeno **una review approvata** da un altro membro del team
   prima del merge (nessun self-merge, anche per cambi piccoli).
4. Merge preferito: **squash and merge**, con il titolo del commit
   risultante che segue la convenzione sopra — mantiene `main` lineare e
   leggibile.
5. Chi apre la PR è responsabile di risolvere i conflitti di merge con
   `main`, non chi fa la review.

## Architettura

Prima di aggiungere codice, leggi `ARCHITECTURE.md` — in particolare le
regole di Clean Architecture (§2) e la convenzione XP/REP (§4): non sono
opzionali, esistono per evitare bug di race condition e logica duplicata
già visti in questo progetto.
