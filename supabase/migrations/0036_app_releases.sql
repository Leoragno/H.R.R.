-- =====================================================================
-- HRR — Aggiornamento in-app dell'APK Android (distribuita fuori dal Play
-- Store agli amici).
--
-- app_releases: una riga per versione pubblicata. L'app legge la più
-- recente all'avvio/ripresa e, se il suo version_code è più alto di
-- quello installato, propone di aggiornare scaricando l'APK giusta per
-- l'ABI del telefono (vedi lib/features/app_update/).
--
-- publish_app_release: chiamata solo da scripts/release_android.sh col
-- ruolo postgres (supabase db query --linked), mai dall'app: inserisce la
-- release e una notifica 'app_update' per ogni profilo, che il trigger di
-- 0016/0019 trasforma in push.
-- =====================================================================

create table if not exists public.app_releases (
  version_code int primary key,
  version_name text not null,
  -- { "<abi>": { "url": "...", "sha256": "..." } }, es. arm64-v8a,
  -- armeabi-v7a, x86_64 — un'APK per ABI (flutter build apk
  -- --split-per-abi), molto più leggera di quella universale.
  apks jsonb not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.app_releases enable row level security;

drop policy if exists "app_releases_read" on public.app_releases;
create policy "app_releases_read" on public.app_releases
  for select to authenticated using (true);

create or replace function public.publish_app_release(
  p_version_code int,
  p_version_name text,
  p_apks jsonb,
  p_notes text default null
) returns int
language plpgsql security definer as $$
declare
  v_notified int;
begin
  insert into public.app_releases (version_code, version_name, apks, notes)
    values (p_version_code, p_version_name, p_apks, p_notes);

  insert into public.notifications (profile_id, type, title, body, data)
    select p.id, 'app_update', 'Aggiornamento disponibile 🚀',
      'È uscita HRR ' || p_version_name || '. Apri l''app e tocca Aggiorna.' ||
        coalesce(' Novità: ' || nullif(trim(p_notes), ''), ''),
      jsonb_build_object('version_code', p_version_code,
        'version_name', p_version_name)
    from public.profiles p;
  get diagnostics v_notified = row_count;
  return v_notified;
end;
$$;

-- Solo il proprietario del progetto (postgres, via CLI) pubblica release:
-- nessun utente dell'app deve poter spammare notifiche a tutti.
revoke execute on function public.publish_app_release(int, text, jsonb, text)
  from public, anon, authenticated;

notify pgrst, 'reload schema';
