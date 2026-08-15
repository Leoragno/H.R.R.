-- =====================================================================
-- HRR — Decadimento e contrattacco dei pentagoni (punto 1 del brief
-- "sistema di ritorno quotidiano").
--
-- Cambio di comportamento importante: l'acquisizione dei pentagoni non è
-- più un tracking ambientale indipendente (bastava camminare/guidare con
-- la schermata Gioca aperta) — ora avviene SOLO come parte di una guida
-- registrata (Trip), usando il punteggio di guida finale di quel viaggio
-- per decidere i contrattacchi. Lato client questo sposta la chiamata a
-- claim_territory_cells da GameController a TripLiveController.finishTrip,
-- dopo che complete_trip ha calcolato il punteggio (vedi 0024/0025).
--
-- Decadimento gestito "pigro" (nessun cron): un pentagono con claimed_at
-- più vecchio della soglia è trattato come libero da chi lo legge/scrive,
-- senza bisogno di una riga cancellata da un job periodico — stesso
-- principio delle celle mai scritte (0008: "una cella senza riga è
-- libera"), qui esteso a "una cella con riga troppo vecchia è libera".
-- =====================================================================

-- Soglia di decadimento come funzione, non literal duplicato: un solo
-- punto da cambiare quando (come previsto dal brief) scenderà a 7 giorni
-- con più utenti attivi per città.
create or replace function public.territory_decay_days() returns int
language sql immutable as $$ select 14 $$;

alter table public.territory_cells add column if not exists drive_score smallint;

-- ---------------------------------------------------------------------
-- claim_territory_cells — riscritta per il punteggio di guida:
--   * cella libera O decaduta -> claim fresco, salva drive_score.
--   * cella già mia (non decaduta) -> rinnova solo claimed_at, NESSUN
--     punto assegnato (brief: "riguidare su un pentagono già proprio ne
--     rinnova la scadenza ma non assegna punti").
--   * cella di un altro (non decaduta) -> passa di mano solo se
--     p_drive_score è non-null e supera quello registrato; notifica push
--     immediata al proprietario precedente. p_drive_score null (viaggio
--     troppo corto per un punteggio onesto) non può mai rubare, solo
--     rivendicare celle libere.
-- ---------------------------------------------------------------------
-- "create or replace" con un parametro in più crea un overload invece di
-- sostituire la firma esistente (stesso caso di complete_trip in 0007) —
-- va droppata esplicitamente, altrimenti la vecchia versione a 1
-- parametro resta chiamabile e ignora decadimento/punteggio.
drop function if exists public.claim_territory_cells(jsonb);

create or replace function public.claim_territory_cells(p_cells jsonb, p_drive_score int default null)
returns table (fresh_count int, stolen_count int)
language plpgsql security definer as $$
declare
  v_profile_id uuid := auth.uid();
  v_actor_username text;
  v_cell jsonb;
  v_q int;
  v_r int;
  v_row public.territory_cells;
  v_expired boolean;
  v_fresh int := 0;
  v_stolen int := 0;
begin
  if v_profile_id is null then
    raise exception 'Non autenticato';
  end if;

  for v_cell in select * from jsonb_array_elements(p_cells)
  loop
    v_q := (v_cell->>'q')::int;
    v_r := (v_cell->>'r')::int;

    select * into v_row from public.territory_cells
      where q = v_q and r = v_r for update;

    v_expired := v_row is not null
      and v_row.claimed_at < now() - (public.territory_decay_days() || ' days')::interval;

    if v_row is null or v_expired then
      insert into public.territory_cells (q, r, owner_id, claimed_at, drive_score)
        values (v_q, v_r, v_profile_id, now(), p_drive_score)
        on conflict (q, r) do update
          set owner_id = excluded.owner_id, claimed_at = excluded.claimed_at,
              drive_score = excluded.drive_score;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, case when v_expired then v_row.owner_id else null end);
      v_fresh := v_fresh + 1;

    elsif v_row.owner_id = v_profile_id then
      update public.territory_cells set claimed_at = now() where q = v_q and r = v_r;
      -- Nessun log/punto: non è un claim, solo un rinnovo.

    elsif p_drive_score is not null and p_drive_score > coalesce(v_row.drive_score, -1) then
      update public.territory_cells
        set owner_id = v_profile_id, claimed_at = now(), drive_score = p_drive_score
        where q = v_q and r = v_r;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, v_row.owner_id);
      v_stolen := v_stolen + 1;

      if v_actor_username is null then
        select username into v_actor_username from public.profiles where id = v_profile_id;
      end if;
      insert into public.notifications (profile_id, type, title, body, data)
        values (v_row.owner_id, 'territory_stolen', 'Territorio conquistato! 🏴',
          coalesce(v_actor_username, 'Qualcuno') ||
            ' ti ha rubato un pentagono con un punteggio di guida di ' || p_drive_score || '.',
          jsonb_build_object('q', v_q, 'r', v_r, 'actor_id', v_profile_id,
            'drive_score', p_drive_score));
    end if;
    -- p_drive_score troppo basso/null contro un proprietario reale: nessun
    -- cambiamento, nessun log — il tentativo semplicemente non riesce.
  end loop;

  return query select v_fresh, v_stolen;
end;
$$;

grant execute on function public.claim_territory_cells(jsonb, int) to authenticated;

-- ---------------------------------------------------------------------
-- territory_cells_near — aggiunge claimed_at (per lo sbiadimento a 3
-- giorni dalla scadenza, calcolato lato client) e drive_score; esclude le
-- celle decadute (trattate come libere, mai restituite).
-- ---------------------------------------------------------------------
-- Postgres non permette di cambiare le colonne di ritorno di una funzione
-- esistente con "create or replace" a parità di firma degli argomenti —
-- va droppata esplicitamente prima di ricrearla con le colonne in più.
drop function if exists public.territory_cells_near(int, int, int, int);

create or replace function public.territory_cells_near(
  p_q int, p_r int, p_cols int, p_rows int
) returns table (q int, r int, owner_id uuid, crew_id uuid, claimed_at timestamptz, drive_score smallint)
language sql stable as $$
  select tc.q, tc.r, tc.owner_id, p.crew_id, tc.claimed_at, tc.drive_score
  from public.territory_cells tc
  join public.profiles p on p.id = tc.owner_id
  where tc.q between p_q - p_cols and p_q + p_cols
    and tc.r between p_r - p_rows and p_r + p_rows
    and tc.claimed_at >= now() - (public.territory_decay_days() || ' days')::interval;
$$;

grant execute on function public.territory_cells_near(int, int, int, int) to authenticated;

-- ---------------------------------------------------------------------
-- my_territories — per la schermata "I miei territori" (brief, punto 1):
-- tutte le celle del chiamante non decadute, più vicine a scadere prima.
-- Indipendente dalla finestra (q,r) di territory_cells_near, che copre
-- solo l'area visibile sulla mappa in un dato momento.
-- ---------------------------------------------------------------------
create or replace function public.my_territories()
returns table (q int, r int, claimed_at timestamptz, drive_score smallint)
language sql stable as $$
  select tc.q, tc.r, tc.claimed_at, tc.drive_score
  from public.territory_cells tc
  where tc.owner_id = auth.uid()
    and tc.claimed_at >= now() - (public.territory_decay_days() || ' days')::interval
  order by tc.claimed_at asc;
$$;

grant execute on function public.my_territories() to authenticated;
