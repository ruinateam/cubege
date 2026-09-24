-- Restoring an exam is owner-only and never exposes questions' keys or solutions.

create or replace function public.active_attempt(target_attempt uuid)
returns table(
  attempt_id uuid,
  variant_slug text,
  variant_title text,
  expires_at timestamptz,
  score_scale smallint[],
  answers jsonb
)
language sql
security definer
set search_path = public
as $$
  select
    a.id,
    v.slug,
    v.title,
    a.expires_at,
    v.score_scale,
    coalesce(
      jsonb_object_agg(aa.position::text, aa.value) filter (where aa.position is not null),
      '{}'::jsonb
    )
  from public.attempts a
  join public.exam_variants v on v.id = a.variant_id
  left join public.attempt_answers aa on aa.attempt_id = a.id
  where a.id = target_attempt
    and a.user_id = auth.uid()
    and a.submitted_at is null
    and a.expires_at > now()
  group by a.id, v.slug, v.title, v.score_scale;
$$;

-- An expired attempt must not prevent a user from starting the same variant again.
create or replace function public.start_attempt(target_slug text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
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
  where user_id = auth.uid()
    and variant_id = target_variant
    and submitted_at is null
    and expires_at > now()
  order by created_at desc
  limit 1;

  if attempt is null then
    insert into public.attempts (user_id, variant_id, expires_at)
    values (auth.uid(), target_variant, now() + make_interval(secs => variant_duration))
    returning id into attempt;
  end if;

  return attempt;
end;
$$;

grant execute on function public.active_attempt(uuid) to authenticated;
grant execute on function public.start_attempt(text) to authenticated;
