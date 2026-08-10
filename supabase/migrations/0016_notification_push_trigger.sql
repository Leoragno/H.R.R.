-- =====================================================================
-- HRR — Push su nuova notifica: quando una riga arriva in `notifications`
-- (già scritta da più funzioni server, missioni/achievement/rating —
-- vedi 0001/0003/0004), questo trigger chiama la Edge Function
-- `send-push` via pg_net, che a sua volta manda la push FCM ai device
-- registrati in `push_tokens` per quel profilo.
--
-- L'URL della function e la chiave di servizio sono PLACEHOLDER: vanno
-- sostituiti a mano dopo `supabase functions deploy send-push` (vedi
-- supabase/functions/send-push/index.ts). Finché restano ai valori
-- placeholder, la chiamata fallisce silenziosamente (blocco exception
-- sotto) — l'insert della notifica (e la sua visibilità in-app via
-- Realtime) non è MAI condizionato dalla riuscita della push.
-- =====================================================================

create extension if not exists pg_net;

create or replace function public.notify_push_on_notification_insert()
returns trigger
language plpgsql security definer as $$
declare
  -- TODO: sostituisci con l'URL reale dopo il deploy della function,
  -- es. https://<project-ref>.functions.supabase.co/send-push
  v_edge_function_url text := 'https://REPLACE_WITH_YOUR_PROJECT.functions.supabase.co/send-push';
  -- TODO: sostituisci con la tua service role key (Project Settings ->
  -- API). Necessaria perché la function verifica il chiamante.
  v_service_role_key text := 'REPLACE_WITH_SERVICE_ROLE_KEY';
begin
  if v_edge_function_url like '%REPLACE_WITH%' then
    return new; -- non ancora configurata: nessun invio, nessun errore
  end if;

  perform net.http_post(
    url := v_edge_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := jsonb_build_object(
      'profile_id', new.profile_id,
      'title', new.title,
      'body', new.body,
      'data', new.data
    )
  );
  return new;
exception when others then
  -- Una push fallita/Edge Function irraggiungibile non deve mai far
  -- fallire l'insert della notifica: resta comunque salvata e visibile
  -- in-app via Realtime a prescindere da questo trigger.
  return new;
end;
$$;

drop trigger if exists trg_notify_push_on_notification_insert on public.notifications;
create trigger trg_notify_push_on_notification_insert
  after insert on public.notifications
  for each row execute function public.notify_push_on_notification_insert();
