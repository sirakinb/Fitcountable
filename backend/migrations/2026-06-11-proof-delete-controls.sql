create or replace function public.fc_remove_proof_media(
  p_post_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_updated int := 0;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  update proof_posts
  set
    media_url = null,
    media_type = null,
    updated_at = now()
  where id = p_post_id
    and user_id = v_user_id;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'Proof post not found';
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'photo_removed'
  );
end;
$$;

create or replace function public.fc_delete_proof_post(
  p_post_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_deleted int := 0;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  delete from proof_posts
  where id = p_post_id
    and user_id = v_user_id;

  get diagnostics v_deleted = row_count;
  if v_deleted = 0 then
    raise exception 'Proof post not found';
  end if;

  return jsonb_build_object(
    'ok', true,
    'status', 'deleted'
  );
end;
$$;
