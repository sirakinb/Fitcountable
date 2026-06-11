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
    select jsonb_agg(feed.post_json order by feed.created_at desc)
    from (
      select
        pp.created_at,
        jsonb_build_object(
          'id', pp.id,
          'user_id', pp.user_id,
          'display_name', coalesce(p.display_name, 'Fitcountable User'),
          'avatar_url', p.avatar_url,
          'workout_id', pp.workout_id,
          'meal_id', pp.meal_id,
          'workout_title',
            case
              when pp.proof_kind = 'food' then coalesce(initcap(m.meal_type) || ' proof', 'Food proof')
              else coalesce(w.title, 'Gym proof')
            end,
          'duration_minutes', w.duration_minutes,
          'set_count', coalesce(ws.set_count, 0),
          'caption', pp.caption,
          'visibility', pp.visibility,
          'media_url', case when pp.media_url like 'data:%' then null else pp.media_url end,
          'media_type', case when pp.media_url like 'data:%' then null else pp.media_type end,
          'proof_kind', pp.proof_kind,
          'detail_lines', pp.detail_lines,
          'created_at', pp.created_at,
          'relationship',
            case
              when pp.user_id = v_user_id then 'own'
              when public.fc_are_friends(v_user_id, pp.user_id) then 'friend'
              else 'public'
            end
        ) as post_json
      from proof_posts pp
      join profiles p on p.user_id = pp.user_id
      left join workouts w on w.id = pp.workout_id
      left join meals m on m.id = pp.meal_id
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
      order by pp.created_at desc
      limit 50
    ) feed
  ), '[]'::jsonb);
end;
$$;

create or replace function public.fc_create_proof_post(
  p_workout_id uuid default null,
  p_meal_id uuid default null,
  p_caption text default null,
  p_visibility text default 'friends',
  p_media_url text default null,
  p_media_type text default null,
  p_source text default 'fitcountable',
  p_proof_kind text default 'workout',
  p_detail_lines jsonb default '[]'::jsonb,
  p_media_base64 text default null
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
  v_proof_kind text := lower(trim(coalesce(p_proof_kind, 'workout')));
  v_media_url text := nullif(trim(p_media_url), '');
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;
  if v_visibility not in ('private', 'friends', 'public') then
    v_visibility := 'friends';
  end if;
  if v_proof_kind not in ('workout', 'food', 'general') then
    v_proof_kind := 'general';
  end if;
  if p_workout_id is not null and not exists (
    select 1 from workouts where id = p_workout_id and user_id = v_user_id
  ) then
    raise exception 'Workout not found';
  end if;
  if p_meal_id is not null and not exists (
    select 1 from meals where id = p_meal_id and user_id = v_user_id
  ) then
    raise exception 'Meal not found';
  end if;

  if v_media_url is null and nullif(trim(p_media_base64), '') is not null then
    v_media_url := 'data:' || coalesce(nullif(trim(p_media_type), ''), 'image/jpeg') || ';base64,' || trim(p_media_base64);
  end if;

  insert into proof_posts (user_id, workout_id, meal_id, media_url, media_type, caption, visibility, source, proof_kind, detail_lines)
  values (
    v_user_id,
    p_workout_id,
    p_meal_id,
    v_media_url,
    nullif(trim(p_media_type), ''),
    nullif(trim(p_caption), ''),
    v_visibility,
    coalesce(nullif(trim(p_source), ''), 'fitcountable'),
    v_proof_kind,
    coalesce(p_detail_lines, '[]'::jsonb)
  )
  returning * into v_post;

  return jsonb_build_object(
    'id', v_post.id,
    'user_id', v_post.user_id,
    'display_name', coalesce((select display_name from profiles where user_id = v_user_id), 'Fitcountable User'),
    'avatar_url', (select avatar_url from profiles where user_id = v_user_id),
    'workout_id', v_post.workout_id,
    'meal_id', v_post.meal_id,
    'workout_title',
      case
        when v_post.proof_kind = 'food' then coalesce((select initcap(meal_type) || ' proof' from meals where id = v_post.meal_id), 'Food proof')
        else coalesce((select title from workouts where id = v_post.workout_id), 'Gym proof')
      end,
    'duration_minutes', (select duration_minutes from workouts where id = v_post.workout_id),
    'set_count', coalesce((select count(*)::int from workout_sets where workout_id = v_post.workout_id), 0),
    'caption', v_post.caption,
    'visibility', v_post.visibility,
    'media_url', case when v_post.media_url like 'data:%' then null else v_post.media_url end,
    'media_type', case when v_post.media_url like 'data:%' then null else v_post.media_type end,
    'proof_kind', v_post.proof_kind,
    'detail_lines', v_post.detail_lines,
    'created_at', v_post.created_at,
    'relationship', 'own'
  );
end;
$$;
