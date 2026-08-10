-- =====================================================================
-- HRR — "Gioca": conquista territorio via GPS a esagoni (vedi tab Gioca,
-- Guida.dc.html righe 720-835). Griglia esagonale fissa a coordinate
-- assiali (q,r): origine e hex-size sono condivisi col client
-- (lib/features/game/domain/hex_grid.dart, stessa formula 1:1) così la
-- stessa cella produce sempre la stessa chiave (q,r) ovunque — nessuna
-- negoziazione né generazione della griglia lato server. Solo le celle
-- possedute vengono scritte: una cella senza riga è "libera", il client
-- la disegna localmente senza bisogno di leggerla dal server.
--
-- Scope deliberatamente ridotto rispetto al mockup: i tab "Amici"/"Italy"
-- della classifica territorio NON sono stati riportati — stessa scelta
-- già fatta per leaderboard_global in 0005 ("classifica amici"/"locale"
-- rimandate: richiedono grafo amicizie strutturato e dati di posizione
-- strutturati, nessuno dei due utilizzabile qui). Il concetto di "club"
-- del mockup mappa 1:1 su `crews`/`crew_id`, già reale in questo schema.
-- =====================================================================

create table public.territory_cells (
  q int not null,
  r int not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (q, r)
);

create index idx_territory_cells_owner on public.territory_cells(owner_id);

-- Log di ogni claim (cella libera o furto). Alimenta le classifiche
-- "Top ladri / in crescita / in calo" su una finestra temporale senza mai
-- dover scansionare/derivare lo stato da territory_cells, che tiene solo
-- il possesso corrente.
create table public.territory_claim_log (
  id uuid primary key default uuid_generate_v4(),
  q int not null,
  r int not null,
  claimant_id uuid not null references public.profiles(id) on delete cascade,
  previous_owner_id uuid references public.profiles(id) on delete set null,
  claimed_at timestamptz not null default now()
);

create index idx_territory_claim_log_claimant on public.territory_claim_log(claimant_id, claimed_at desc);
create index idx_territory_claim_log_victim on public.territory_claim_log(previous_owner_id, claimed_at desc);

alter table public.territory_cells enable row level security;
alter table public.territory_claim_log enable row level security;

-- Mappa e log leggibili da chiunque sia autenticato — servono per
-- disegnare il territorio altrui e per le classifiche. Nessuna policy di
-- insert/update/delete: l'unica scrittura possibile è tramite la RPC
-- claim_territory_cells (security definer), stesso principio anti-cheat
-- di complete_trip in 0002 — il client manda solo fatti grezzi (celle
-- attraversate), il server decide chi possiede cosa.
create policy "territory_cells_select_all" on public.territory_cells for select using (true);
create policy "territory_claim_log_select_all" on public.territory_claim_log for select using (true);

-- ---------------------------------------------------------------------
-- claim_territory_cells — unico entrypoint di scrittura. Riceve le celle
-- (q,r) attraversate dall'utente autenticato (deduplicate lato client),
-- rivendica quelle libere o altrui (furto, loggato in
-- territory_claim_log), ignora quelle già sue. `for update` sulla riga
-- di ogni cella serializza due giocatori che rivendicano la stessa cella
-- nello stesso istante. Ritorna i conteggi fresh/rubate della sola
-- chiamata corrente, per il banner "Nuovi esagoni +N · Rubati N".
-- ---------------------------------------------------------------------
create or replace function public.claim_territory_cells(p_cells jsonb)
returns table (fresh_count int, stolen_count int)
language plpgsql security definer as $$
declare
  v_profile_id uuid := auth.uid();
  v_cell jsonb;
  v_q int;
  v_r int;
  v_owner uuid;
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

    select tc.owner_id into v_owner from public.territory_cells tc
      where tc.q = v_q and tc.r = v_r for update;

    if v_owner is null then
      insert into public.territory_cells (q, r, owner_id) values (v_q, v_r, v_profile_id);
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, null);
      v_fresh := v_fresh + 1;
    elsif v_owner <> v_profile_id then
      update public.territory_cells set owner_id = v_profile_id, claimed_at = now()
        where q = v_q and r = v_r;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, v_owner);
      v_stolen := v_stolen + 1;
    end if;
    -- v_owner = v_profile_id: già mia, nessuna scrittura/log.
  end loop;

  return query select v_fresh, v_stolen;
end;
$$;

grant execute on function public.claim_territory_cells(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- territory_cells_near — celle possedute in una finestra rettangolare
-- (in coordinate assiali) attorno al focus corrente, per disegnare la
-- mappa. Solo celle con proprietario: quelle libere sono implicite lato
-- client (nessuna riga = libera), non servono andata/ritorno per quelle.
-- ---------------------------------------------------------------------
create or replace function public.territory_cells_near(
  p_q int, p_r int, p_cols int, p_rows int
) returns table (q int, r int, owner_id uuid, crew_id uuid)
language sql stable as $$
  select tc.q, tc.r, tc.owner_id, p.crew_id
  from public.territory_cells tc
  join public.profiles p on p.id = tc.owner_id
  where tc.q between p_q - p_cols and p_q + p_cols
    and tc.r between p_r - p_rows and p_r + p_rows;
$$;

grant execute on function public.territory_cells_near(int, int, int, int) to authenticated;

-- ---------------------------------------------------------------------
-- territory_cell_count — totale celle possedute da un profilo, per il
-- badge area del giocatore (che può avere territorio fuori dalla finestra
-- disegnata da territory_cells_near). Fuori da territory_standings perché
-- quella è limitata a `p_limit` righe: un giocatore fuori classifica
-- perderebbe comunque il proprio conteggio.
-- ---------------------------------------------------------------------
create or replace function public.territory_cell_count(p_profile_id uuid)
returns int
language sql stable as $$
  select count(*)::int from public.territory_cells where owner_id = p_profile_id;
$$;

grant execute on function public.territory_cell_count(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- territory_standings — classifica territorio, globale o filtrata sulla
-- crew di chi chiama. growth/decline calcolati su una finestra
-- `p_period_days` da territory_claim_log — stesso principio di
-- leaderboard_global (0005): aggregato server-side, il client non legge
-- mai le righe grezze del log per questo scopo.
-- ---------------------------------------------------------------------
create or replace function public.territory_standings(
  p_scope text default 'global',
  p_crew_id uuid default null,
  p_period_days int default 30,
  p_limit int default 50
) returns table (
  profile_id uuid,
  username text,
  display_name text,
  avatar_url text,
  crew_id uuid,
  crew_tag text,
  cell_count bigint,
  stolen bigint,
  growth bigint,
  decline bigint
)
language plpgsql stable as $$
declare
  v_window_start timestamptz := now() - (p_period_days || ' days')::interval;
begin
  if p_scope not in ('global', 'crew') then
    raise exception 'Scope non valido: % (atteso global|crew)', p_scope;
  end if;
  if p_scope = 'crew' and p_crew_id is null then
    raise exception 'p_crew_id richiesto per scope=crew';
  end if;

  return query
    select p.id, p.username, p.display_name, p.avatar_url, p.crew_id, c.tag,
      owned.cell_count,
      coalesce(stolen_log.n, 0),
      coalesce(growth_log.n, 0),
      coalesce(decline_log.n, 0)
    from public.profiles p
    left join public.crews c on c.id = p.crew_id
    join lateral (
      select count(*) cell_count from public.territory_cells tc where tc.owner_id = p.id
    ) owned on true
    left join lateral (
      select count(*) n from public.territory_claim_log l
      where l.claimant_id = p.id and l.previous_owner_id is not null and l.claimed_at >= v_window_start
    ) stolen_log on true
    left join lateral (
      select count(*) n from public.territory_claim_log l
      where l.claimant_id = p.id and l.claimed_at >= v_window_start
    ) growth_log on true
    left join lateral (
      select count(*) n from public.territory_claim_log l
      where l.previous_owner_id = p.id and l.claimed_at >= v_window_start
    ) decline_log on true
    where owned.cell_count > 0
      and (p_scope = 'global' or p.crew_id = p_crew_id)
    order by owned.cell_count desc
    limit p_limit;
end;
$$;

grant execute on function public.territory_standings(text, uuid, int, int) to authenticated;

-- Realtime: la mappa territorio deve riflettere subito i furti degli
-- altri giocatori mentre sei sulla schermata Gioca (stesso trattamento
-- già riservato a profiles/cars in 0002).
alter publication supabase_realtime add table public.territory_cells;
