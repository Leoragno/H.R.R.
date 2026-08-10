-- =====================================================================
-- HRR — Token push (FCM) per dispositivo, associati al profilo. Servono
-- alla Edge Function `send-push` (vedi supabase/functions/send-push) per
-- sapere a quali dispositivi inviare quando arriva una nuova riga in
-- `notifications`.
--
-- Scrittura solo via RPC (mai insert/update/delete diretti dal client):
-- lo stesso dispositivo può passare da un account a un altro (logout/
-- login), quindi riassegnare un token esistente richiede di "liberarlo"
-- dal profilo precedente — logica che una semplice policy RLS
-- (auth.uid() = profile_id valutato sulla riga ESISTENTE) non
-- permetterebbe di per sé.
-- =====================================================================

create table public.push_tokens (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_push_tokens_profile on public.push_tokens(profile_id);

alter table public.push_tokens enable row level security;

-- Nessuna policy insert/update/delete: solo le RPC sotto (security
-- definer) scrivono. La Edge Function legge con la service role key
-- (bypassa RLS), mai con la chiave anonima del client.
create policy "push_tokens_select_self" on public.push_tokens
  for select using (auth.uid() = profile_id);

create or replace function public.register_push_token(
  p_token text,
  p_platform text
) returns void
language plpgsql security definer as $$
begin
  if p_platform not in ('android', 'ios', 'web') then
    raise exception 'Piattaforma non valida: % (atteso android|ios|web)', p_platform;
  end if;

  -- Stesso device, account diverso da prima: libera il token dal
  -- profilo precedente prima di assegnarlo al chiamante corrente.
  delete from public.push_tokens
    where token = p_token and profile_id <> auth.uid();

  insert into public.push_tokens (profile_id, token, platform, updated_at)
  values (auth.uid(), p_token, p_platform, now())
  on conflict (token) do update set
    platform = excluded.platform,
    updated_at = now();
end;
$$;

grant execute on function public.register_push_token(text, text) to authenticated;

create or replace function public.unregister_push_token(p_token text)
returns void
language plpgsql security definer as $$
begin
  delete from public.push_tokens
    where token = p_token and profile_id = auth.uid();
end;
$$;

grant execute on function public.unregister_push_token(text) to authenticated;
