-- Fitcountable database plan.
-- The Insforge-ready version applied to the linked project is in:
-- backend/insforge/schema.sql

create table if not exists users (
  id uuid primary key,
  apple_user_id text unique,
  email_private_relay_safe text,
  created_at timestamptz default now()
);

create table if not exists profiles (
  user_id uuid primary key references users(id),
  display_name text not null,
  avatar_url text,
  goal_type text not null,
  height numeric,
  weight numeric,
  target_weight numeric,
  activity_level text,
  training_experience text,
  privacy_mode text not null default 'private'
);

create table if not exists goals (
  id uuid primary key,
  user_id uuid references users(id),
  calories int,
  protein_g int,
  carbs_g int,
  fat_g int,
  weekly_workouts int,
  target_pace text,
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists workouts (
  id uuid primary key,
  user_id uuid references users(id),
  title text not null,
  started_at timestamptz,
  duration_minutes int,
  source text not null,
  notes text,
  visibility text not null default 'private'
);

create table if not exists workout_sets (
  id uuid primary key,
  workout_id uuid references workouts(id),
  exercise_name text not null,
  set_index int not null,
  reps int,
  weight numeric,
  unit text default 'lb',
  rpe numeric,
  notes text
);

create table if not exists meals (
  id uuid primary key,
  user_id uuid references users(id),
  meal_type text not null,
  logged_at timestamptz default now(),
  source text not null,
  notes text
);

create table if not exists food_items (
  id uuid primary key,
  meal_id uuid references meals(id),
  name text not null,
  quantity_text text,
  calories int,
  protein_g numeric,
  carbs_g numeric,
  fat_g numeric,
  confidence numeric
);

create table if not exists ai_commands (
  id uuid primary key,
  user_id uuid references users(id),
  raw_text text not null,
  action_type text,
  model text,
  parsed_json jsonb,
  status text not null,
  error text,
  created_at timestamptz default now()
);

create table if not exists follows (
  follower_id uuid references users(id),
  following_id uuid references users(id),
  status text not null,
  created_at timestamptz default now(),
  primary key (follower_id, following_id)
);

create table if not exists accountability_settings (
  user_id uuid primary key references users(id),
  enabled boolean default false,
  visibility_scope text default 'friends',
  proof_required boolean default false,
  missed_day_threshold int default 2
);

create table if not exists proof_posts (
  id uuid primary key,
  user_id uuid references users(id),
  workout_id uuid references workouts(id),
  media_url text,
  caption text,
  visibility text default 'friends',
  created_at timestamptz default now()
);

create table if not exists nudges (
  id uuid primary key,
  sender_id uuid references users(id),
  recipient_id uuid references users(id),
  type text,
  message text,
  status text,
  created_at timestamptz default now()
);

create table if not exists subscriptions (
  user_id uuid primary key references users(id),
  revenuecat_app_user_id text,
  entitlement text,
  active boolean default false,
  product_id text,
  expires_at timestamptz
);

create table if not exists events (
  id uuid primary key,
  user_id uuid references users(id),
  name text not null,
  properties_json jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);
