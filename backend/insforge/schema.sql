create extension if not exists pgcrypto;

create table if not exists profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Fitcountable User',
  avatar_url text,
  goal_type text not null default 'recomp',
  height numeric,
  weight numeric,
  target_weight numeric,
  activity_level text,
  training_experience text,
  privacy_mode text not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists onboarding_answers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  value_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, key)
);

create table if not exists goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  calories int,
  protein_g int,
  carbs_g int,
  fat_g int,
  weekly_workouts int,
  target_pace text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  started_at timestamptz not null default now(),
  duration_minutes int,
  source text not null default 'manual',
  notes text,
  visibility text not null default 'private',
  created_at timestamptz not null default now()
);

create table if not exists workout_sets (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references workouts(id) on delete cascade,
  exercise_name text not null,
  set_index int not null,
  reps int,
  weight numeric,
  unit text not null default 'lb',
  rpe numeric,
  notes text
);

create table if not exists meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_type text not null,
  logged_at timestamptz not null default now(),
  source text not null default 'manual',
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists food_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references meals(id) on delete cascade,
  name text not null,
  quantity_text text,
  calories int,
  protein_g numeric,
  carbs_g numeric,
  fat_g numeric,
  confidence numeric
);

create table if not exists saved_foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  normalized_name text not null,
  quantity_text text,
  calories int,
  protein_g numeric,
  carbs_g numeric,
  fat_g numeric,
  confidence numeric,
  source text not null default 'ai',
  last_logged_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists ai_commands (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  raw_text text not null,
  action_type text,
  model text,
  parsed_json jsonb,
  status text not null default 'submitted',
  error text,
  created_at timestamptz not null default now()
);

create table if not exists follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id)
);

create table if not exists accountability_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  visibility_scope text not null default 'friends',
  proof_required boolean not null default false,
  missed_day_threshold int not null default 2
);

create table if not exists proof_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_id uuid references workouts(id) on delete set null,
  meal_id uuid references meals(id) on delete set null,
  media_url text,
  media_type text,
  caption text,
  visibility text not null default 'friends',
  source text not null default 'fitcountable',
  proof_kind text not null default 'workout',
  detail_lines jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists nudges (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  type text,
  message text,
  status text not null default 'queued',
  created_at timestamptz not null default now()
);

create table if not exists subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revenuecat_app_user_id text,
  entitlement text,
  active boolean not null default false,
  product_id text,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  name text not null,
  properties_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;
alter table onboarding_answers enable row level security;
alter table goals enable row level security;
alter table workouts enable row level security;
alter table workout_sets enable row level security;
alter table meals enable row level security;
alter table food_items enable row level security;
alter table saved_foods enable row level security;
alter table ai_commands enable row level security;
alter table follows enable row level security;
alter table accountability_settings enable row level security;
alter table proof_posts enable row level security;
alter table nudges enable row level security;
alter table subscriptions enable row level security;
alter table events enable row level security;

create policy profiles_owner_all on profiles for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy onboarding_owner_all on onboarding_answers for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy goals_owner_all on goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy workouts_owner_all on workouts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy workout_sets_owner_all on workout_sets for all using (
  exists (select 1 from workouts where workouts.id = workout_sets.workout_id and workouts.user_id = auth.uid())
) with check (
  exists (select 1 from workouts where workouts.id = workout_sets.workout_id and workouts.user_id = auth.uid())
);
create policy meals_owner_all on meals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy food_items_owner_all on food_items for all using (
  exists (select 1 from meals where meals.id = food_items.meal_id and meals.user_id = auth.uid())
) with check (
  exists (select 1 from meals where meals.id = food_items.meal_id and meals.user_id = auth.uid())
);
create policy saved_foods_owner_all on saved_foods for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy ai_commands_owner_all on ai_commands for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy follows_participant_read on follows for select using (auth.uid() = follower_id or auth.uid() = following_id);
create policy follows_owner_write on follows for insert with check (auth.uid() = follower_id);
create policy accountability_owner_all on accountability_settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy proof_posts_owner_all on proof_posts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy nudges_participant_read on nudges for select using (auth.uid() = sender_id or auth.uid() = recipient_id);
create policy nudges_sender_insert on nudges for insert with check (auth.uid() = sender_id);
create policy subscriptions_owner_read on subscriptions for select using (auth.uid() = user_id);
create policy events_owner_insert on events for insert with check (auth.uid() = user_id or user_id is null);
