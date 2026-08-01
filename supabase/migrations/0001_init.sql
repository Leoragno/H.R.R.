-- =====================================================================
-- HRR (HeatRacers) — Initial Supabase schema
-- Postgres 15+ / Supabase. Run in order. Uses auth.users as identity root.
-- =====================================================================

create extension if not exists "uuid-ossp";
create extension if not exists postgis; -- for geography/heatmap queries

-- ---------------------------------------------------------------------
-- PROFILES (1:1 with auth.users)
-- ---------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  display_name text not null,
  avatar_url text,
  bio text,
  level int not null default 1,
  xp bigint not null default 0,
  rep bigint not null default 0,
  title text default 'Rookie Driver',
  total_km numeric(12,2) not null default 0,
  total_trips int not null default 0,
  driving_score numeric(3,1) not null default 5.0, -- A+ style score, 0-10 internally
  crew_id uuid, -- FK aggiunta sotto via ALTER, dopo che crews esiste (crews.owner_id referenzia profiles)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- CREWS (clans)
-- ---------------------------------------------------------------------
create table public.crews (
  id uuid primary key default uuid_generate_v4(),
  name text unique not null,
  tag text unique not null check (char_length(tag) between 2 and 6),
  description text,
  emblem_url text,
  level int not null default 1,
  xp bigint not null default 0,
  owner_id uuid not null references public.profiles(id),
  member_count int not null default 1,
  created_at timestamptz not null default now()
);

alter table public.profiles
  add constraint fk_profiles_crew foreign key (crew_id) references public.crews(id) on delete set null;

create table public.crew_members (
  crew_id uuid not null references public.crews(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','officer','member')),
  joined_at timestamptz not null default now(),
  primary key (crew_id, profile_id)
);

-- ---------------------------------------------------------------------
-- CARS (Garage)
-- ---------------------------------------------------------------------
create table public.cars (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  make text not null,
  model text not null,
  year int,
  nickname text,
  color text,
  photo_url text,
  level int not null default 1,
  xp bigint not null default 0,
  total_km numeric(12,2) not null default 0,
  customization jsonb not null default '{}'::jsonb, -- livery, rims, neon color etc
  is_active boolean not null default true, -- currently selected car for trips
  created_at timestamptz not null default now()
);

create index idx_cars_owner on public.cars(owner_id);

-- ---------------------------------------------------------------------
-- TRIPS
-- ---------------------------------------------------------------------
create table public.trips (
  id uuid primary key default uuid_generate_v4(),
  driver_id uuid not null references public.profiles(id) on delete cascade,
  car_id uuid references public.cars(id) on delete set null,
  started_at timestamptz not null,
  ended_at timestamptz,
  distance_km numeric(10,2) not null default 0,
  duration_seconds int not null default 0,
  avg_speed_kmh numeric(6,2),
  max_speed_kmh numeric(6,2),
  route geography(LineString, 4326), -- PostGIS path
  xp_earned int not null default 0,
  rep_earned int not null default 0,
  driving_score numeric(3,1),
  status text not null default 'active' check (status in ('active','completed','discarded')),
  created_at timestamptz not null default now()
);

create index idx_trips_driver on public.trips(driver_id, started_at desc);
create index idx_trips_route on public.trips using gist(route);

-- ---------------------------------------------------------------------
-- XP / LEVEL LOG (audit trail — never mutate profile totals without a log row)
-- ---------------------------------------------------------------------
create table public.xp_events (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  source text not null, -- 'trip','mission','badge','event'
  source_id uuid,
  xp_delta int not null default 0,
  rep_delta int not null default 0,
  created_at timestamptz not null default now()
);

create index idx_xp_events_profile on public.xp_events(profile_id, created_at desc);

-- ---------------------------------------------------------------------
-- BADGES
-- ---------------------------------------------------------------------
create table public.badges (
  id uuid primary key default uuid_generate_v4(),
  code text unique not null,
  name text not null,
  description text,
  icon_url text,
  rarity text not null default 'common' check (rarity in ('common','uncommon','rare','epic','legendary'))
);

create table public.profile_badges (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (profile_id, badge_id)
);

-- ---------------------------------------------------------------------
-- MISSIONS
-- ---------------------------------------------------------------------
create table public.missions (
  id uuid primary key default uuid_generate_v4(),
  code text unique not null,
  title text not null,
  description text,
  type text not null check (type in ('daily','weekly','crew','event')),
  target_value numeric not null,
  target_metric text not null, -- 'km','trips','spots','likes' etc
  xp_reward int not null default 0,
  rep_reward int not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.mission_progress (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  current_value numeric not null default 0,
  completed boolean not null default false,
  completed_at timestamptz,
  primary key (profile_id, mission_id)
);

-- ---------------------------------------------------------------------
-- EVENTS
-- ---------------------------------------------------------------------
create table public.events (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  banner_url text,
  location geography(Point, 4326),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  crew_id uuid references public.crews(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.event_participants (
  event_id uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);

-- ---------------------------------------------------------------------
-- CAR SPOTTING (community posts)
-- ---------------------------------------------------------------------
create table public.spots (
  id uuid primary key default uuid_generate_v4(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  photo_url text not null,
  caption text,
  location geography(Point, 4326),
  detected_make text,       -- filled by AI recognition pipeline
  detected_model text,
  detected_year int,
  detected_category text,
  detected_rarity text check (detected_rarity in ('common','uncommon','rare','epic','legendary')),
  detection_confidence numeric(4,3), -- 0.000 - 1.000
  like_count int not null default 0,
  dislike_count int not null default 0,
  comment_count int not null default 0,
  save_count int not null default 0,
  created_at timestamptz not null default now()
);

create index idx_spots_author on public.spots(author_id, created_at desc);
create index idx_spots_created on public.spots(created_at desc);

create table public.spot_reactions (
  spot_id uuid not null references public.spots(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (reaction in ('like','dislike')),
  created_at timestamptz not null default now(),
  primary key (spot_id, profile_id)
);

create table public.spot_comments (
  id uuid primary key default uuid_generate_v4(),
  spot_id uuid not null references public.spots(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 500),
  created_at timestamptz not null default now()
);

create table public.spot_saves (
  spot_id uuid not null references public.spots(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (spot_id, profile_id)
);

-- ---------------------------------------------------------------------
-- SOCIAL: friends
-- ---------------------------------------------------------------------
create table public.friendships (
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','blocked')),
  created_at timestamptz not null default now(),
  primary key (requester_id, addressee_id)
);

-- ---------------------------------------------------------------------
-- CHAT (crew realtime messages)
-- ---------------------------------------------------------------------
create table public.chat_messages (
  id uuid primary key default uuid_generate_v4(),
  crew_id uuid not null references public.crews(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index idx_chat_crew on public.chat_messages(crew_id, created_at desc);

-- ---------------------------------------------------------------------
-- NOTIFICATIONS
-- ---------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  type text not null, -- 'like','comment','friend_request','mission_complete','event',...
  title text not null,
  body text,
  data jsonb default '{}'::jsonb,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_notifications_profile on public.notifications(profile_id, read, created_at desc);

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
alter table public.profiles enable row level security;
alter table public.crews enable row level security;
alter table public.crew_members enable row level security;
alter table public.cars enable row level security;
alter table public.trips enable row level security;
alter table public.xp_events enable row level security;
alter table public.badges enable row level security;
alter table public.profile_badges enable row level security;
alter table public.missions enable row level security;
alter table public.mission_progress enable row level security;
alter table public.events enable row level security;
alter table public.event_participants enable row level security;
alter table public.spots enable row level security;
alter table public.spot_reactions enable row level security;
alter table public.spot_comments enable row level security;
alter table public.spot_saves enable row level security;
alter table public.friendships enable row level security;
alter table public.chat_messages enable row level security;
alter table public.notifications enable row level security;

-- PROFILES: public read, self write
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_update_self" on public.profiles for update using (auth.uid() = id);
create policy "profiles_insert_self" on public.profiles for insert with check (auth.uid() = id);

-- CREWS: public read, owner/officer manage
create policy "crews_select_all" on public.crews for select using (true);
create policy "crews_insert_auth" on public.crews for insert with check (auth.uid() = owner_id);
create policy "crews_update_owner" on public.crews for update using (auth.uid() = owner_id);

create policy "crew_members_select_all" on public.crew_members for select using (true);
create policy "crew_members_insert_self" on public.crew_members for insert with check (auth.uid() = profile_id);
create policy "crew_members_delete_self_or_owner" on public.crew_members for delete
  using (auth.uid() = profile_id or auth.uid() in (select owner_id from public.crews where id = crew_id));

-- CARS: public read (garage is showcase), owner write
create policy "cars_select_all" on public.cars for select using (true);
create policy "cars_insert_owner" on public.cars for insert with check (auth.uid() = owner_id);
create policy "cars_update_owner" on public.cars for update using (auth.uid() = owner_id);
create policy "cars_delete_owner" on public.cars for delete using (auth.uid() = owner_id);

-- TRIPS: owner full access, friends can view (simplified: public read for leaderboard purposes)
create policy "trips_select_all" on public.trips for select using (true);
create policy "trips_insert_owner" on public.trips for insert with check (auth.uid() = driver_id);
create policy "trips_update_owner" on public.trips for update using (auth.uid() = driver_id);

-- XP EVENTS: self read only, inserted by backend functions (service role)
create policy "xp_events_select_self" on public.xp_events for select using (auth.uid() = profile_id);

-- BADGES: public catalogue read
create policy "badges_select_all" on public.badges for select using (true);
create policy "profile_badges_select_all" on public.profile_badges for select using (true);

-- MISSIONS: public catalogue read
create policy "missions_select_all" on public.missions for select using (true);
create policy "mission_progress_select_self" on public.mission_progress for select using (auth.uid() = profile_id);
create policy "mission_progress_update_self" on public.mission_progress for update using (auth.uid() = profile_id);
create policy "mission_progress_insert_self" on public.mission_progress for insert with check (auth.uid() = profile_id);

-- EVENTS: public read
create policy "events_select_all" on public.events for select using (true);
create policy "event_participants_select_all" on public.event_participants for select using (true);
create policy "event_participants_insert_self" on public.event_participants for insert with check (auth.uid() = profile_id);

-- SPOTS (Car Spotting): public read, author write
create policy "spots_select_all" on public.spots for select using (true);
create policy "spots_insert_author" on public.spots for insert with check (auth.uid() = author_id);
create policy "spots_update_author" on public.spots for update using (auth.uid() = author_id);
create policy "spots_delete_author" on public.spots for delete using (auth.uid() = author_id);

create policy "spot_reactions_select_all" on public.spot_reactions for select using (true);
create policy "spot_reactions_upsert_self" on public.spot_reactions for insert with check (auth.uid() = profile_id);
create policy "spot_reactions_update_self" on public.spot_reactions for update using (auth.uid() = profile_id);
create policy "spot_reactions_delete_self" on public.spot_reactions for delete using (auth.uid() = profile_id);

create policy "spot_comments_select_all" on public.spot_comments for select using (true);
create policy "spot_comments_insert_author" on public.spot_comments for insert with check (auth.uid() = author_id);
create policy "spot_comments_delete_author" on public.spot_comments for delete using (auth.uid() = author_id);

create policy "spot_saves_select_self" on public.spot_saves for select using (auth.uid() = profile_id);
create policy "spot_saves_insert_self" on public.spot_saves for insert with check (auth.uid() = profile_id);
create policy "spot_saves_delete_self" on public.spot_saves for delete using (auth.uid() = profile_id);

-- FRIENDSHIPS: participants only
create policy "friendships_select_participant" on public.friendships for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
create policy "friendships_insert_requester" on public.friendships for insert with check (auth.uid() = requester_id);
create policy "friendships_update_participant" on public.friendships for update
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- CHAT: crew members only
create policy "chat_select_crew_member" on public.chat_messages for select
  using (auth.uid() in (select profile_id from public.crew_members where crew_id = chat_messages.crew_id));
create policy "chat_insert_crew_member" on public.chat_messages for insert
  with check (auth.uid() = author_id and auth.uid() in
    (select profile_id from public.crew_members where crew_id = chat_messages.crew_id));

-- NOTIFICATIONS: self only
create policy "notifications_select_self" on public.notifications for select using (auth.uid() = profile_id);
create policy "notifications_update_self" on public.notifications for update using (auth.uid() = profile_id);

-- =====================================================================
-- REALTIME publication (for Supabase Realtime — chat, live leaderboard)
-- =====================================================================
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.spot_reactions;
