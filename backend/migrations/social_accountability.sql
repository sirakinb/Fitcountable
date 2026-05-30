alter table follows
  add column if not exists accepted_at timestamptz,
  add column if not exists responded_at timestamptz;

alter table proof_posts
  add column if not exists media_type text,
  add column if not exists source text not null default 'fitcountable',
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.fc_are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from follows f
    where f.status = 'accepted'
      and (
        (f.follower_id = a and f.following_id = b)
        or (f.follower_id = b and f.following_id = a)
      )
  );
$$;

create or replace function public.fc_bootstrap_profile(
  p_display_name text default null,
  p_avatar_url text default null,
  p_goal_type text default null,
  p_privacy_mode text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile profiles%rowtype;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  insert into profiles (user_id, display_name, avatar_url, goal_type, privacy_mode, updated_at)
  values (
    v_user_id,
    coalesce(nullif(trim(p_display_name), ''), 'Fitcountable User'),
    nullif(trim(p_avatar_url), ''),
    coalesce(nullif(trim(p_goal_type), ''), 'recomp'),
    coalesce(nullif(trim(p_privacy_mode), ''), 'private'),
    now()
  )
  on conflict (user_id) do update set
    display_name = coalesce(nullif(trim(excluded.display_name), ''), profiles.display_name),
    avatar_url = coalesce(excluded.avatar_url, profiles.avatar_url),
    goal_type = coalesce(nullif(trim(excluded.goal_type), ''), profiles.goal_type),
    privacy_mode = coalesce(nullif(trim(excluded.privacy_mode), ''), profiles.privacy_mode),
    updated_at = now()
  returning * into v_profile;

  insert into accountability_settings (user_id, enabled, visibility_scope)
  values (v_user_id, false, 'friends')
  on conflict (user_id) do nothing;

  return jsonb_build_object(
    'id', v_profile.user_id,
    'user_id', v_profile.user_id,
    'display_name', v_profile.display_name,
    'avatar_url', v_profile.avatar_url,
    'goal_type', v_profile.goal_type,
    'privacy_mode', v_profile.privacy_mode
  );
end;
$$;

create or replace function public.fc_social_search_profiles(p_query text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.user_id,
      'display_name', p.display_name,
      'avatar_url', p.avatar_url,
      'privacy_mode', p.privacy_mode,
      'relationship_status',
        case
          when f_out.status is not null then f_out.status
          when f_in.status = 'pending' then 'requested_you'
          when f_in.status = 'accepted' then 'accepted'
          else 'none'
        end
    ) order by p.display_name)
    from profiles p
    left join follows f_out
      on f_out.follower_id = v_user_id and f_out.following_id = p.user_id
    left join follows f_in
      on f_in.follower_id = p.user_id and f_in.following_id = v_user_id
    where p.user_id <> v_user_id
      and length(trim(coalesce(p_query, ''))) >= 2
      and p.display_name ilike '%' || trim(p_query) || '%'
    limit 20
  ), '[]'::jsonb);
end;
$$;

create or replace function public.fc_follow_user(p_target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_status text := 'pending';
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;
  if p_target_user_id is null or p_target_user_id = v_user_id then
    raise exception 'Invalid target user';
  end if;
  if not exists (select 1 from profiles where user_id = p_target_user_id) then
    raise exception 'User not found';
  end if;

  if exists (
    select 1 from follows
    where follower_id = p_target_user_id
      and following_id = v_user_id
      and status = 'pending'
  ) then
    update follows
      set status = 'accepted', accepted_at = now(), responded_at = now()
      where follower_id = p_target_user_id and following_id = v_user_id;
    v_status := 'accepted';
  else
    insert into follows (follower_id, following_id, status)
    values (v_user_id, p_target_user_id, 'pending')
    on conflict (follower_id, following_id) do update
      set status = case when follows.status = 'accepted' then 'accepted' else 'pending' end
    returning status into v_status;
  end if;

  return jsonb_build_object('ok', true, 'status', v_status, 'target_user_id', p_target_user_id);
end;
$$;

create or replace function public.fc_respond_follow(p_follower_id uuid, p_action text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_action text := lower(trim(coalesce(p_action, '')));
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  if v_action in ('accept', 'accepted') then
    update follows
      set status = 'accepted', accepted_at = now(), responded_at = now()
      where follower_id = p_follower_id
        and following_id = v_user_id
        and status = 'pending';
    return jsonb_build_object('ok', true, 'status', 'accepted', 'follower_id', p_follower_id);
  end if;

  if v_action in ('decline', 'reject', 'delete', 'remove', 'cancel') then
    delete from follows
      where (
        follower_id = p_follower_id and following_id = v_user_id
      ) or (
        follower_id = v_user_id and following_id = p_follower_id
      );
    return jsonb_build_object('ok', true, 'status', 'removed', 'follower_id', p_follower_id);
  end if;

  raise exception 'Unsupported action';
end;
$$;

create or replace function public.fc_friends_list()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  return jsonb_build_object(
    'friends', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.user_id,
        'display_name', p.display_name,
        'avatar_url', p.avatar_url,
        'privacy_mode', p.privacy_mode,
        'relationship_status', 'accepted',
        'streak', 0,
        'status', 'Approved friend'
      ) order by p.display_name)
      from follows f
      join profiles p on p.user_id = case when f.follower_id = v_user_id then f.following_id else f.follower_id end
      where f.status = 'accepted'
        and (f.follower_id = v_user_id or f.following_id = v_user_id)
    ), '[]'::jsonb),
    'incoming', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.user_id,
        'display_name', p.display_name,
        'avatar_url', p.avatar_url,
        'privacy_mode', p.privacy_mode,
        'relationship_status', 'requested_you',
        'streak', 0,
        'status', 'Wants to follow you'
      ) order by f.created_at desc)
      from follows f
      join profiles p on p.user_id = f.follower_id
      where f.following_id = v_user_id and f.status = 'pending'
    ), '[]'::jsonb),
    'outgoing', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.user_id,
        'display_name', p.display_name,
        'avatar_url', p.avatar_url,
        'privacy_mode', p.privacy_mode,
        'relationship_status', 'pending',
        'streak', 0,
        'status', 'Request sent'
      ) order by f.created_at desc)
      from follows f
      join profiles p on p.user_id = f.following_id
      where f.follower_id = v_user_id and f.status = 'pending'
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.fc_create_proof_post(
  p_workout_id uuid default null,
  p_caption text default null,
  p_visibility text default 'friends',
  p_media_url text default null,
  p_media_type text default null,
  p_source text default 'fitcountable'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_post proof_posts%rowtype;
  v_visibility text := lower(trim(coalesce(p_visibility, 'friends')));
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;
  if v_visibility not in ('private', 'friends', 'public') then
    v_visibility := 'friends';
  end if;
  if p_workout_id is not null and not exists (
    select 1 from workouts where id = p_workout_id and user_id = v_user_id
  ) then
    raise exception 'Workout not found';
  end if;

  insert into proof_posts (user_id, workout_id, media_url, media_type, caption, visibility, source)
  values (v_user_id, p_workout_id, nullif(trim(p_media_url), ''), nullif(trim(p_media_type), ''), nullif(trim(p_caption), ''), v_visibility, coalesce(nullif(trim(p_source), ''), 'fitcountable'))
  returning * into v_post;

  return jsonb_build_object(
    'id', v_post.id,
    'user_id', v_post.user_id,
    'display_name', coalesce((select display_name from profiles where user_id = v_user_id), 'Fitcountable User'),
    'avatar_url', (select avatar_url from profiles where user_id = v_user_id),
    'workout_id', v_post.workout_id,
    'workout_title', coalesce((select title from workouts where id = v_post.workout_id), 'Workout proof'),
    'duration_minutes', (select duration_minutes from workouts where id = v_post.workout_id),
    'set_count', coalesce((select count(*)::int from workout_sets where workout_id = v_post.workout_id), 0),
    'caption', v_post.caption,
    'visibility', v_post.visibility,
    'media_url', v_post.media_url,
    'media_type', v_post.media_type,
    'created_at', v_post.created_at,
    'relationship', 'own'
  );
end;
$$;

create or replace function public.fc_proof_feed(p_target_user_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', pp.id,
      'user_id', pp.user_id,
      'display_name', coalesce(p.display_name, 'Fitcountable User'),
      'avatar_url', p.avatar_url,
      'workout_id', pp.workout_id,
      'workout_title', coalesce(w.title, 'Workout proof'),
      'duration_minutes', w.duration_minutes,
      'set_count', coalesce(ws.set_count, 0),
      'caption', pp.caption,
      'visibility', pp.visibility,
      'media_url', pp.media_url,
      'media_type', pp.media_type,
      'created_at', pp.created_at,
      'relationship',
        case
          when pp.user_id = v_user_id then 'own'
          when public.fc_are_friends(v_user_id, pp.user_id) then 'friend'
          else 'public'
        end
    ) order by pp.created_at desc)
    from proof_posts pp
    join profiles p on p.user_id = pp.user_id
    left join workouts w on w.id = pp.workout_id
    left join (
      select workout_id, count(*)::int as set_count
      from workout_sets
      group by workout_id
    ) ws on ws.workout_id = pp.workout_id
    where (p_target_user_id is null or pp.user_id = p_target_user_id)
      and (
        pp.user_id = v_user_id
        or pp.visibility = 'public'
        or (pp.visibility = 'friends' and public.fc_are_friends(v_user_id, pp.user_id))
      )
    limit 50
  ), '[]'::jsonb);
end;
$$;

create or replace function public.fc_profile_view(p_target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile profiles%rowtype;
  v_relationship text := 'none';
  v_can_view boolean := false;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  select * into v_profile from profiles where user_id = p_target_user_id;
  if not found then
    raise exception 'Profile not found';
  end if;

  if p_target_user_id = v_user_id then
    v_relationship := 'own';
    v_can_view := true;
  elsif public.fc_are_friends(v_user_id, p_target_user_id) then
    v_relationship := 'friend';
    v_can_view := true;
  elsif v_profile.privacy_mode = 'public' then
    v_relationship := 'public';
    v_can_view := true;
  end if;

  return jsonb_build_object(
    'profile', jsonb_build_object(
      'id', v_profile.user_id,
      'display_name', v_profile.display_name,
      'avatar_url', v_profile.avatar_url,
      'privacy_mode', v_profile.privacy_mode,
      'relationship_status', v_relationship,
      'can_view', v_can_view
    ),
    'stats', jsonb_build_object(
      'workouts', (select count(*) from workouts where user_id = p_target_user_id),
      'proof_posts', (select count(*) from proof_posts where user_id = p_target_user_id and (v_can_view or visibility = 'public'))
    ),
    'proof_posts', case when v_can_view then public.fc_proof_feed(p_target_user_id) else '[]'::jsonb end
  );
end;
$$;
