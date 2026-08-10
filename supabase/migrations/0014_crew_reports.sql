-- =====================================================================
-- HRR — Segnalazioni Velox/Pattuglia della crew ("Velox Crew" / "Pattuglia
-- Crew" nella sezione Guida). Un membro segnala un punto GPS, visibile in
-- realtime a tutta la sua crew; la validità (90 minuti) è applicata solo
-- lato client (qui teniamo semplicemente created_at) — niente TTL/cron
-- lato DB, la riga resta ma il client la ignora dopo la scadenza (stesso
-- principio "il client filtra il grezzo" già usato altrove, es. GameState
-- coi fix GPS stantii).
-- =====================================================================

create table public.crew_reports (
  id uuid primary key default uuid_generate_v4(),
  crew_id uuid not null references public.crews(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (category in ('velox', 'pattuglia')),
  lat double precision not null,
  lon double precision not null,
  created_at timestamptz not null default now()
);

-- Le segnalazioni più vecchie di qualche ora non servono più a nessuna
-- query (client-side si scartano oltre i 90 minuti): l'indice tiene
-- comunque veloce sia il fetch iniziale per crew sia l'ordinamento.
create index idx_crew_reports_crew_recent
  on public.crew_reports(crew_id, created_at desc);

alter table public.crew_reports enable row level security;

create policy "crew_reports_select_crew_member" on public.crew_reports
  for select using (
    auth.uid() in (
      select profile_id from public.crew_members
      where crew_id = crew_reports.crew_id
    )
  );

create policy "crew_reports_insert_crew_member" on public.crew_reports
  for insert with check (
    auth.uid() = reporter_id
    and auth.uid() in (
      select profile_id from public.crew_members
      where crew_id = crew_reports.crew_id
    )
  );

-- Nessuna policy update/delete: una segnalazione non si modifica, scade e
-- basta (lato client). Realtime: serve la tabella nella pubblicazione
-- perché il client possa usare `.stream()` (stesso pattern di profiles,
-- vedi 0002_trip_economy_and_realtime.sql).
alter publication supabase_realtime add table public.crew_reports;
