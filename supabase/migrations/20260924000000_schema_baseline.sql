-- Canonical schema snapshot for an empty Cubege Supabase project.
-- Source: live project ncclidrfaemzdefrzomv, inspected 2026-09-24.
-- This file deliberately excludes exam content and all user data.
-- Do not run it against the live project: apply only later migrations there.

create extension if not exists pgcrypto with schema extensions;

create type public.nickname_status as enum ('pending', 'approved', 'rejected');

create table public.exam_variants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  duration_seconds integer not null check (duration_seconds > 0),
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  score_scale smallint[] not null
);

create table public.questions (
  variant_id uuid not null references public.exam_variants(id) on delete cascade,
  position smallint not null check (position between 1 and 100),
  kind text not null check (kind in ('short', 'long')),
  points smallint not null check (points > 0),
  prompt text not null,
  options jsonb,
  answer text,
  solution text,
  image_path text,
  primary key (variant_id, position)
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nickname text unique,
  nickname_status public.nickname_status not null default 'pending',
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  device_id text,
  constraint nickname_format check (nickname is null or nickname ~ '^[A-Za-z0-9_]{3,16}$')
);

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  variant_id uuid not null references public.exam_variants(id),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  primary_score smallint,
  secondary_score smallint,
  expires_at timestamptz not null,
  leaderboard_visible boolean not null default false,
  leaderboard_visibility_decided_at timestamptz
);

create table public.attempt_answers (
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  position smallint not null check (position between 1 and 100),
  value text not null default '',
  updated_at timestamptz not null default now(),
  awarded_points smallint not null default 0,
  graded_by uuid references auth.users(id),
  graded_at timestamptz,
  primary key (attempt_id, position)
);

create index attempts_variant_id_idx on public.attempts (variant_id);
create unique index one_open_attempt_per_variant
  on public.attempts (user_id, variant_id) where submitted_at is null;
create index profiles_reviewed_by_idx on public.profiles (reviewed_by);
create index attempts_public_leaderboard_idx on public.attempts (secondary_score desc, submitted_at asc)
  where submitted_at is not null and leaderboard_visible;
create index attempt_answers_graded_by_idx on public.attempt_answers (graded_by);

alter table public.exam_variants enable row level security;
alter table public.questions enable row level security;
alter table public.profiles enable row level security;
alter table public.attempts enable row level security;
alter table public.attempt_answers enable row level security;

create policy "published variants visible" on public.exam_variants
  for select to authenticated using (is_published);
create policy "own profile visible" on public.profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy "own attempts visible" on public.attempts
  for select to authenticated using (user_id = (select auth.uid()));

grant select on public.profiles to authenticated;

insert into storage.buckets (id, name, public)
values ('exam-images', 'exam-images', true);
create policy "exam images are publicly readable" on storage.objects
  for select to anon, authenticated using (bucket_id = 'exam-images');

set check_function_bodies = off;
CREATE OR REPLACE FUNCTION public.attempt_long_answers(target_attempt uuid)
 RETURNS TABLE(question_position smallint, prompt text, max_points smallint, value text, awarded_points smallint, graded boolean, solution text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select q.position, q.prompt, q.points, coalesce(aa.value, ''), coalesce(aa.awarded_points, 0), aa.graded_at is not null, q.solution
  from public.attempts a
  join public.questions q on q.variant_id = a.variant_id and q.kind = 'long'
  left join public.attempt_answers aa on aa.attempt_id = a.id and aa.position = q.position
  where a.id = target_attempt and a.submitted_at is not null and public.is_admin()
  order by q.position;
$function$;

CREATE OR REPLACE FUNCTION public.attempt_results(target_attempt uuid)
 RETURNS TABLE(question_position smallint, is_correct boolean, correct_answer text, solution text, awarded_points smallint, max_points smallint, graded boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select q.position,
    case when q.kind = 'short' then lower(regexp_replace(coalesce(aa.value, ''), '\s', '', 'g')) = lower(q.answer) else null end,
    case when coalesce(aa.value, '') <> '' and q.kind = 'short' then q.answer else null end,
    case when coalesce(aa.value, '') <> '' then q.solution else null end,
    coalesce(aa.awarded_points, 0),
    q.points,
    aa.graded_at is not null
  from public.attempts a
  join public.questions q on q.variant_id = a.variant_id
  left join public.attempt_answers aa on aa.attempt_id = a.id and aa.position = q.position
  where a.id = target_attempt and a.user_id = auth.uid() and a.submitted_at is not null
  order by q.position;
$function$;

CREATE OR REPLACE FUNCTION public.attempts_for_grading()
 RETURNS TABLE(attempt_id uuid, user_email text, variant_slug text, variant_title text, submitted_at timestamp with time zone, primary_score smallint, secondary_score smallint, long_answered bigint, long_graded bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select a.id, u.email, v.slug, v.title, a.submitted_at, a.primary_score, a.secondary_score,
    count(aa.position) filter (where q.kind = 'long' and coalesce(aa.value, '') <> ''),
    count(aa.position) filter (where q.kind = 'long' and aa.graded_at is not null)
  from public.attempts a
  join public.exam_variants v on v.id = a.variant_id
  join auth.users u on u.id = a.user_id
  left join public.questions q on q.variant_id = a.variant_id and q.kind = 'long'
  left join public.attempt_answers aa on aa.attempt_id = a.id and aa.position = q.position
  where a.submitted_at is not null and public.is_admin()
  group by a.id, u.email, v.slug, v.title, a.submitted_at, a.primary_score, a.secondary_score
  order by a.submitted_at desc;
$function$;

CREATE OR REPLACE FUNCTION public.claim_guest_data(device text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  guest_id uuid;
  n int;
  moved_attempts int := 0;
  moved_guests int := 0;
begin
  if not exists (select 1 from auth.users where id = auth.uid() and email is not null) then
    raise exception 'Only for linked users';
  end if;
  if device is null or device = '' then
    return jsonb_build_object('attempts', 0, 'guests', 0);
  end if;
  insert into public.profiles(user_id) values (auth.uid()) on conflict do nothing;
  for guest_id in
    select p.user_id
    from public.profiles p
    join auth.users u on u.id = p.user_id
    where p.device_id = device
      and p.user_id <> auth.uid()
      and u.email is null
      and coalesce(u.raw_app_meta_data->'providers' ? 'twitch', false) = false
  loop
    update public.attempts set user_id = auth.uid() where user_id = guest_id;
    get diagnostics n = row_count;
    moved_attempts := moved_attempts + n;
    update public.profiles t
    set nickname = g.nickname, nickname_status = g.nickname_status,
        reviewed_at = g.reviewed_at, reviewed_by = g.reviewed_by
    from public.profiles g
    where t.user_id = auth.uid() and g.user_id = guest_id
      and t.nickname is null and g.nickname is not null;
    delete from public.profiles where user_id = guest_id;
    moved_guests := moved_guests + 1;
  end loop;
  return jsonb_build_object('attempts', moved_attempts, 'guests', moved_guests);
end;$function$;

CREATE OR REPLACE FUNCTION public.create_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin insert into public.profiles(user_id) values(new.id) on conflict do nothing; return new; end;$function$;

CREATE OR REPLACE FUNCTION public.grade_answer(target_attempt uuid, target_position smallint, awarded smallint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  max_pts smallint;
  score smallint;
  scale smallint[];
begin
  if not public.is_admin() then raise exception 'Forbidden'; end if;
  if not exists (select 1 from public.attempts where id = target_attempt and submitted_at is not null) then
    raise exception 'Attempt is not submitted';
  end if;
  select q.points into max_pts
  from public.questions q
  join public.attempts a on a.variant_id = q.variant_id
  where a.id = target_attempt and q.position = target_position and q.kind = 'long';
  if max_pts is null then raise exception 'Only long answers can be graded'; end if;
  if awarded < 0 or awarded > max_pts then raise exception 'Points out of range'; end if;
  update public.attempt_answers
  set awarded_points = awarded, graded_by = auth.uid(), graded_at = now()
  where attempt_id = target_attempt and position = target_position;
  if not found then raise exception 'Answer not found'; end if;
  select (coalesce(sum(q.points) filter (where q.kind = 'short' and lower(regexp_replace(coalesce(aa.value, ''), '\s', '', 'g')) = lower(q.answer)), 0)
    + coalesce(sum(aa.awarded_points) filter (where q.kind = 'long'), 0))::smallint
    into score
  from public.questions q
  join public.attempts a on a.variant_id = q.variant_id
  left join public.attempt_answers aa on aa.attempt_id = a.id and aa.position = q.position
  where a.id = target_attempt;
  select v.score_scale into scale
  from public.exam_variants v
  join public.attempts a on a.variant_id = v.id
  where a.id = target_attempt;
  update public.attempts
  set primary_score = score,
      secondary_score = scale[least(score + 1, array_length(scale, 1))]
  where id = target_attempt;
end; $function$;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from auth.users where id = auth.uid() and raw_user_meta_data ->> 'role' = 'admin');
$function$;

create or replace function public.leaderboard(limit_n integer default 20)
returns table(
  nickname text,
  generated_nickname boolean,
  verified boolean,
  is_current_user boolean,
  best_secondary smallint,
  completed bigint,
  latest timestamptz
)
language sql security definer set search_path = public as $$
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
  where a.submitted_at is not null and a.leaderboard_visible
  group by a.user_id, p.nickname, p.nickname_status
  order by max(a.secondary_score) desc nulls last, max(a.submitted_at) asc
  limit least(greatest(limit_n, 1), 20);
$$;

CREATE OR REPLACE FUNCTION public.list_variants()
 RETURNS TABLE(slug text, title text, duration_seconds integer, question_count bigint, max_primary bigint, score_scale smallint[])
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select v.slug, v.title, v.duration_seconds, count(q.position), coalesce(sum(q.points), 0), v.score_scale
  from public.exam_variants v
  left join public.questions q on q.variant_id = v.id
  where v.is_published
  group by v.slug, v.title, v.duration_seconds, v.score_scale, v.created_at
  order by v.created_at;
$function$;

CREATE OR REPLACE FUNCTION public.pending_nicknames()
 RETURNS TABLE(user_id uuid, user_email text, nickname text, created_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.user_id, u.email, p.nickname, p.created_at
  from public.profiles p
  join auth.users u on u.id = p.user_id
  where p.nickname is not null and p.nickname_status = 'pending' and public.is_admin()
  order by p.created_at;
$function$;

CREATE OR REPLACE FUNCTION public.request_nickname(requested_nickname text)
 RETURNS nickname_status
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  linked_twitch boolean;
begin
  if requested_nickname !~ '^[A-Za-z0-9_]{3,16}$' then
    raise exception 'Use 3-16 Latin letters, digits, or underscore';
  end if;
  select exists (
    select 1 from auth.users
    where id = auth.uid()
      and (
        raw_app_meta_data->'providers' ? 'twitch'
        or raw_app_meta_data->>'provider' = 'twitch'
      )
  ) into linked_twitch;
  if linked_twitch then
    begin
      insert into public.profiles(user_id, nickname, nickname_status, reviewed_at, reviewed_by)
      values (auth.uid(), requested_nickname, 'approved', now(), auth.uid())
      on conflict (user_id) do update set
        nickname = excluded.nickname,
        nickname_status = 'approved',
        reviewed_at = now(),
        reviewed_by = excluded.reviewed_by
      where profiles.nickname_status <> 'approved';
    exception when unique_violation then
      raise exception 'Nickname is already taken';
    end;
    if not found then raise exception 'Nickname is already approved'; end if;
    return 'approved';
  end if;
  begin
    insert into public.profiles(user_id, nickname, nickname_status, reviewed_at, reviewed_by)
    values (auth.uid(), requested_nickname, 'pending', null, null)
    on conflict (user_id) do update set
      nickname = excluded.nickname,
      nickname_status = 'pending',
      reviewed_at = null,
      reviewed_by = null
    where profiles.nickname_status <> 'approved';
  exception when unique_violation then
    raise exception 'Nickname is already taken';
  end;
  if not found then raise exception 'Nickname is already approved'; end if;
  return 'pending';
end;$function$;

CREATE OR REPLACE FUNCTION public.review_nickname(target_user uuid, decision nickname_status)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then raise exception 'Forbidden'; end if;
  if decision not in ('approved', 'rejected') then raise exception 'Invalid decision'; end if;
  update public.profiles
  set nickname_status = decision, reviewed_at = now(), reviewed_by = auth.uid()
  where user_id = target_user and nickname is not null;
  if not found then raise exception 'Nothing to review'; end if;
end; $function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

create or replace function public.save_answer(
  target_attempt uuid,
  target_position smallint,
  submitted_value text
)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if char_length(submitted_value) > 10000 then raise exception 'Answer is too long'; end if;
  if not exists (
    select 1 from public.attempts
    where id = target_attempt
      and user_id = auth.uid()
      and submitted_at is null
      and now() < expires_at
  ) then raise exception 'Attempt unavailable'; end if;
  if not exists (
    select 1 from public.questions q
    join public.attempts a on a.variant_id = q.variant_id
    where a.id = target_attempt and q.position = target_position
  ) then raise exception 'Question unavailable'; end if;

  insert into public.attempt_answers (attempt_id, position, value)
  values (target_attempt, target_position, submitted_value)
  on conflict (attempt_id, position) do update
    set value = excluded.value, updated_at = now();
end;
$$;

CREATE OR REPLACE FUNCTION public.set_device_id(device text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.profiles set device_id = nullif(device, '') where user_id = auth.uid();
$function$;

create or replace function public.start_attempt(target_slug text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  target_variant uuid;
  variant_duration integer;
  attempt uuid;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;

  select id, duration_seconds into target_variant, variant_duration
  from public.exam_variants
  where slug = target_slug and is_published;
  if target_variant is null then raise exception 'Variant not found'; end if;

  select id into attempt
  from public.attempts
  where user_id = auth.uid() and variant_id = target_variant and submitted_at is null;

  if attempt is null then
    insert into public.attempts (user_id, variant_id, expires_at)
    values (auth.uid(), target_variant, now() + make_interval(secs => variant_duration))
    returning id into attempt;
  end if;

  return attempt;
end;
$$;

CREATE OR REPLACE FUNCTION public.submit_attempt(target_attempt uuid)
 RETURNS TABLE(primary_score smallint, secondary_score smallint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  score smallint;
  scale smallint[];
begin
  if not exists (select 1 from public.attempts where id = target_attempt and user_id = auth.uid() and submitted_at is null) then
    raise exception 'Attempt unavailable';
  end if;
  if not exists (select 1 from public.attempt_answers where attempt_id = target_attempt and coalesce(value, '') <> '') then
    raise exception 'Attempt has no answers';
  end if;
  select (coalesce(sum(q.points) filter (where q.kind = 'short' and lower(regexp_replace(coalesce(aa.value, ''), '\s', '', 'g')) = lower(q.answer)), 0)
    + coalesce(sum(aa.awarded_points) filter (where q.kind = 'long'), 0))::smallint
    into score
  from public.questions q
  join public.attempts a on a.variant_id = q.variant_id
  left join public.attempt_answers aa on aa.attempt_id = a.id and aa.position = q.position
  where a.id = target_attempt;
  select v.score_scale into scale
  from public.exam_variants v
  join public.attempts a on a.variant_id = v.id
  where a.id = target_attempt;
  update public.attempts
  set submitted_at = now(),
      primary_score = score,
      secondary_score = scale[least(score + 1, array_length(scale, 1))]
  where id = target_attempt;
  return query select a.primary_score, a.secondary_score from public.attempts a where a.id = target_attempt;
end; $function$;

CREATE OR REPLACE FUNCTION public.sync_twitch_nickname()
 RETURNS nickname_status
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.user_statistics()
 RETURNS TABLE(completed_attempts bigint, best_secondary_score smallint, average_secondary_score numeric, latest_submitted_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$select count(*) filter(where submitted_at is not null),max(secondary_score),round(avg(secondary_score) filter(where submitted_at is not null),1),max(submitted_at) from public.attempts where user_id=auth.uid();$function$;

CREATE OR REPLACE FUNCTION public.variant_questions(target_slug text)
 RETURNS TABLE("position" smallint, kind text, points smallint, prompt text, options jsonb, image_path text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select q.position, q.kind, q.points, q.prompt, q.options, q.image_path
  from public.questions q
  join public.exam_variants v on v.id = q.variant_id
  where v.slug = target_slug and v.is_published
  order by q.position;
$function$;

create or replace function public.attempt_deadline(target_attempt uuid)
returns timestamptz
language plpgsql security definer set search_path = public as $$
declare
  deadline timestamptz;
begin
  select expires_at into deadline
  from public.attempts
  where id = target_attempt and user_id = auth.uid();

  if deadline is null then raise exception 'Attempt unavailable'; end if;
  return deadline;
end;
$$;

create or replace function public.set_attempt_leaderboard_visibility(
  target_attempt uuid,
  visible boolean
)
returns boolean
language plpgsql security definer set search_path = public as $$
begin
  update public.attempts
  set leaderboard_visible = visible,
      leaderboard_visibility_decided_at = now()
  where id = target_attempt
    and user_id = auth.uid()
    and submitted_at is not null;

  if not found then raise exception 'Attempt unavailable'; end if;
  return visible;
end;
$$;

create or replace function public.latest_submitted_attempt()
returns table(
  attempt_id uuid,
  submitted_at timestamptz,
  secondary_score smallint,
  leaderboard_visible boolean,
  leaderboard_visibility_decided_at timestamptz
)
language sql security definer set search_path = public as $$
  select
    a.id,
    a.submitted_at,
    a.secondary_score,
    a.leaderboard_visible,
    a.leaderboard_visibility_decided_at
  from public.attempts a
  where a.user_id = auth.uid() and a.submitted_at is not null
  order by a.submitted_at desc
  limit 1;
$$;

reset check_function_bodies;

revoke all on all functions in schema public from public;
grant execute on function public.leaderboard(integer) to anon, authenticated;
grant execute on function public.list_variants() to anon, authenticated;
grant execute on function public.variant_questions(text) to anon, authenticated;
grant execute on function public.attempt_deadline(uuid) to authenticated;
grant execute on function public.attempt_long_answers(uuid) to authenticated;
grant execute on function public.attempt_results(uuid) to authenticated;
grant execute on function public.attempts_for_grading() to authenticated;
grant execute on function public.claim_guest_data(text) to authenticated;
grant execute on function public.grade_answer(uuid, smallint, smallint) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.latest_submitted_attempt() to authenticated;
grant execute on function public.pending_nicknames() to authenticated;
grant execute on function public.request_nickname(text) to authenticated;
grant execute on function public.review_nickname(uuid, public.nickname_status) to authenticated;
grant execute on function public.save_answer(uuid, smallint, text) to authenticated;
grant execute on function public.set_attempt_leaderboard_visibility(uuid, boolean) to authenticated;
grant execute on function public.set_device_id(text) to authenticated;
grant execute on function public.start_attempt(text) to authenticated;
grant execute on function public.submit_attempt(uuid) to authenticated;
grant execute on function public.sync_twitch_nickname() to authenticated;
grant execute on function public.user_statistics() to authenticated;
