-- =====================================================================
-- HRR — Completa il trigger notifications -> pg_net -> send-push (vedi
-- 0016_notification_push_trigger.sql): sostituisce l'URL/service-role-key
-- placeholder con l'URL reale della Edge Function e la lettura della
-- service role key da Supabase Vault, invece di un literal in chiaro nel
-- codice SQL — la chiave non deve MAI finire in un file versionato.
--
-- La chiave va inserita nel Vault a mano, una sola volta, direttamente
-- dal SQL Editor del progetto live (mai da questo file, mai committata):
--
--   select vault.create_secret(
--     '<service_role_key da Project Settings -> API>',
--     'send_push_service_role_key',
--     'Service role key usata da pg_net per chiamare la Edge Function send-push'
--   );
--
-- Se il secret non esiste ancora (o viene rimosso), il trigger fa un
-- no-op silenzioso: l'insert in `notifications` (e la sua visibilità
-- in-app via Realtime) non è mai condizionato dalla riuscita della push,
-- esattamente come nella versione precedente con URL placeholder.
-- =====================================================================

create or replace function public.notify_push_on_notification_insert()
returns trigger
language plpgsql security definer as $$
declare
  v_edge_function_url text := 'https://kxhjesvojzjbjwzmbcfs.supabase.co/functions/v1/send-push';
  v_service_role_key text;
begin
  select decrypted_secret into v_service_role_key
    from vault.decrypted_secrets
    where name = 'send_push_service_role_key'
    limit 1;

  if v_service_role_key is null then
    return new; -- secret non ancora creato nel Vault: nessun invio, nessun errore
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

-- Trigger già esistente (0016): nessuna modifica necessaria, la funzione
-- sopra viene semplicemente ri-eseguita col nuovo corpo dalla prossima
-- riga inserita in notifications.
