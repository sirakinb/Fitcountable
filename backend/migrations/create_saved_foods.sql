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

alter table saved_foods enable row level security;

do $$
begin
  create policy saved_foods_owner_all on saved_foods
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
exception
  when duplicate_object then null;
end $$;
