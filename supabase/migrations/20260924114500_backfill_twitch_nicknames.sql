-- Apply the automatic Twitch-name rule to existing profiles as well.
insert into public.profiles (user_id, nickname, nickname_status, reviewed_at, reviewed_by)
select
  u.id,
  coalesce(
    nullif(u.raw_user_meta_data->>'preferred_username', ''),
    nullif(u.raw_user_meta_data->>'user_name', ''),
    nullif(u.raw_user_meta_data->>'nickname', '')
  ),
  'approved',
  now(),
  u.id
from auth.users u
where (
    u.raw_app_meta_data->'providers' ? 'twitch'
    or u.raw_app_meta_data->>'provider' = 'twitch'
  )
  and coalesce(
    nullif(u.raw_user_meta_data->>'preferred_username', ''),
    nullif(u.raw_user_meta_data->>'user_name', ''),
    nullif(u.raw_user_meta_data->>'nickname', '')
  ) ~ '^[A-Za-z0-9_]{3,16}$'
  and not exists (
    select 1
    from public.profiles taken
    where taken.nickname = coalesce(
      nullif(u.raw_user_meta_data->>'preferred_username', ''),
      nullif(u.raw_user_meta_data->>'user_name', ''),
      nullif(u.raw_user_meta_data->>'nickname', '')
    )
      and taken.user_id <> u.id
  )
on conflict (user_id) do update set
  nickname = excluded.nickname,
  nickname_status = 'approved',
  reviewed_at = excluded.reviewed_at,
  reviewed_by = excluded.reviewed_by
where public.profiles.nickname_status <> 'approved';
