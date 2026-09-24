-- Translate the first eight hexadecimal UUID characters to a-p so generated
-- leaderboard identities have no digits and render fully in Enchantment.
drop function if exists public.leaderboard(integer);

create function public.leaderboard(limit_n integer default 20)
returns table(
  nickname text,
  generated_nickname boolean,
  verified boolean,
  is_current_user boolean,
  best_secondary smallint,
  completed bigint,
  latest timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    coalesce(
      case when p.nickname_status = 'approved' then p.nickname end,
      translate(substring(replace(a.user_id::text, '-', ''), 1, 8), '0123456789abcdef', 'abcdefghijklmnop')
    ) as nickname,
    coalesce(p.nickname_status <> 'approved' or p.nickname is null, true) as generated_nickname,
    coalesce(exists (
      select 1
      from auth.users u
      where u.id = a.user_id
        and (
          u.raw_app_meta_data->'providers' ? 'twitch'
          or u.raw_app_meta_data->>'provider' = 'twitch'
        )
    ), false) as verified,
    bool_or(a.user_id = auth.uid()) as is_current_user,
    max(a.secondary_score) as best_secondary,
    count(*) as completed,
    max(a.submitted_at) as latest
  from public.attempts a
  left join public.profiles p on p.user_id = a.user_id
  where a.submitted_at is not null
  group by a.user_id, p.nickname, p.nickname_status
  order by max(a.secondary_score) desc nulls last, max(a.submitted_at) asc
  limit least(greatest(limit_n, 1), 20);
$$;

revoke all on function public.leaderboard(integer) from public;
grant execute on function public.leaderboard(integer) to anon, authenticated;
