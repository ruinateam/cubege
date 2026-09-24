-- A Twitch identity supplies a public nickname automatically. Existing
-- manually approved nicknames are preserved, and a taken Twitch login falls
-- back to the generated leaderboard pseudonym.
create or replace function public.sync_twitch_nickname()
returns public.nickname_status
language plpgsql
security definer
set search_path = public
as $$
declare
  twitch_login text;
  assigned_status public.nickname_status;
begin
  select coalesce(
    nullif(raw_user_meta_data->>'preferred_username', ''),
    nullif(raw_user_meta_data->>'user_name', ''),
    nullif(raw_user_meta_data->>'nickname', '')
  )
  into twitch_login
  from auth.users
  where id = auth.uid()
    and (
      raw_app_meta_data->'providers' ? 'twitch'
      or raw_app_meta_data->>'provider' = 'twitch'
    );

  if twitch_login is null or twitch_login !~ '^[A-Za-z0-9_]{3,16}$' then
    return null;
  end if;

  begin
    insert into public.profiles(user_id, nickname, nickname_status, reviewed_at, reviewed_by)
    values (auth.uid(), twitch_login, 'approved', now(), auth.uid())
    on conflict (user_id) do update set
      nickname = excluded.nickname,
      nickname_status = 'approved',
      reviewed_at = now(),
      reviewed_by = excluded.reviewed_by
    where profiles.nickname_status <> 'approved';
  exception when unique_violation then
    return null;
  end;

  if found then return 'approved'; end if;

  select nickname_status into assigned_status
  from public.profiles
  where user_id = auth.uid();
  return assigned_status;
end;
$$;

revoke all on function public.sync_twitch_nickname() from public;
grant execute on function public.sync_twitch_nickname() to authenticated;
