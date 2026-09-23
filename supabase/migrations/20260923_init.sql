-- Draft only: the live schema evolved through later migrations (variant RPCs,
-- score_scale, hardened RLS) applied directly to Supabase. Do not treat this
-- file as the source of truth, and never commit exam content (prompts, options,
-- answers, solutions) — it lives only in the database.
-- Run in the Supabase SQL Editor, or through the Supabase CLI.
create extension if not exists pgcrypto;

create table public.exam_variants (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  duration_seconds integer not null check (duration_seconds > 0),
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.exam_variants(id) on delete cascade,
  position smallint not null check (position between 1 and 100),
  kind text not null check (kind in ('short', 'long')),
  points smallint not null check (points > 0),
  prompt text not null,
  options jsonb,
  answer text, -- never grant direct select access to this table
  solution text,
  unique (variant_id, position)
);

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  variant_id uuid not null references public.exam_variants(id),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  primary_score smallint,
  secondary_score smallint,
  unique (user_id, variant_id, started_at)
);

create table public.attempt_answers (
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  value text not null default '',
  updated_at timestamptz not null default now(),
  primary key (attempt_id, question_id)
);

create type public.nickname_status as enum ('pending', 'approved', 'rejected');

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nickname text unique,
  nickname_status public.nickname_status not null default 'pending',
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  constraint nickname_format check (nickname is null or nickname ~ '^[A-Za-z0-9_]{3,16}$')
);

-- Each authenticated account owns exactly one profile. The raw pending name is never public.
create or replace function public.create_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id) values (new.id) on conflict do nothing;
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.create_profile();

alter table public.exam_variants enable row level security;
alter table public.questions enable row level security;
alter table public.attempts enable row level security;
alter table public.attempt_answers enable row level security;
alter table public.profiles enable row level security;

create policy "Published variants are visible" on public.exam_variants for select using (is_published);
-- A view exposes questions without answer and solution until the user submits.
create view public.published_questions with (security_invoker = true) as
  select q.id, q.variant_id, q.position, q.kind, q.points, q.prompt, q.options
  from public.questions q join public.exam_variants v on v.id = q.variant_id
  where v.is_published;
grant select on public.published_questions to anon, authenticated;

create policy "Users manage their attempts" on public.attempts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users manage own answers" on public.attempt_answers for all to authenticated
  using (exists (select 1 from public.attempts a where a.id = attempt_id and a.user_id = auth.uid()))
  with check (exists (select 1 from public.attempts a where a.id = attempt_id and a.user_id = auth.uid()));
create policy "Users read their profile" on public.profiles for select to authenticated using (user_id = auth.uid());
create policy "Users request a nickname" on public.profiles for update to authenticated
  using (user_id = auth.uid() and nickname_status <> 'approved')
  with check (user_id = auth.uid() and nickname_status = 'pending');

-- Only an admin function may approve/reject nicknames. Replace the email lookup once after your first Twitch login.
create or replace function public.review_nickname(target_user uuid, decision public.nickname_status)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from auth.users where id = auth.uid() and raw_user_meta_data ->> 'role' = 'admin') then
    raise exception 'Forbidden';
  end if;
  if decision not in ('approved', 'rejected') then raise exception 'Invalid decision'; end if;
  update public.profiles set nickname_status = decision, reviewed_at = now(), reviewed_by = auth.uid()
    where user_id = target_user;
end; $$;
revoke all on function public.review_nickname(uuid, public.nickname_status) from public;
grant execute on function public.review_nickname(uuid, public.nickname_status) to authenticated;

-- SECURITY DEFINER is intentional: it can evaluate answer keys while REST clients cannot read them.
create or replace function public.submit_attempt(target_attempt uuid)
returns table(primary_score smallint, secondary_score smallint)
language plpgsql security definer set search_path = public as $$
declare
  owner_id uuid;
  calculated smallint;
begin
  select user_id into owner_id from attempts where id = target_attempt for update;
  if owner_id is null or owner_id <> auth.uid() then raise exception 'Attempt not found'; end if;
  if exists (select 1 from attempts where id = target_attempt and submitted_at is not null) then raise exception 'Attempt already submitted'; end if;
  select coalesce(sum(q.points) filter (where lower(regexp_replace(coalesce(aa.value, ''), '\\s', '', 'g')) = lower(q.answer)), 0)::smallint
    into calculated from questions q left join attempt_answers aa on aa.question_id = q.id and aa.attempt_id = target_attempt
    join attempts a on a.id = target_attempt and a.variant_id = q.variant_id where q.kind = 'short';
  update attempts set submitted_at = now(), primary_score = calculated,
    secondary_score = (array[0,7,14,20,27,34,40,43,46,48,51,54,56,59,62,64,67,70,72,75,78,80,83,86,88,91,94,97,100])[calculated + 1]
  where id = target_attempt;
  return query select a.primary_score, a.secondary_score from attempts a where a.id = target_attempt;
end; $$;
revoke all on function public.submit_attempt(uuid) from public;
grant execute on function public.submit_attempt(uuid) to authenticated;
