create or replace function public.fc_delete_account_data()
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

  delete from nudges where sender_id = v_user_id or recipient_id = v_user_id;
  delete from follows where follower_id = v_user_id or following_id = v_user_id;
  delete from proof_posts where user_id = v_user_id;
  delete from accountability_settings where user_id = v_user_id;
  delete from ai_commands where user_id = v_user_id;
  delete from saved_foods where user_id = v_user_id;
  delete from meals where user_id = v_user_id;
  delete from workouts where user_id = v_user_id;
  delete from goals where user_id = v_user_id;
  delete from onboarding_answers where user_id = v_user_id;
  delete from subscriptions where user_id = v_user_id;
  delete from events where user_id = v_user_id;
  delete from profiles where user_id = v_user_id;
  delete from auth.users where id = v_user_id;

  return jsonb_build_object('ok', true, 'status', 'deleted');
end;
$$;

grant execute on function public.fc_delete_account_data() to authenticated;
