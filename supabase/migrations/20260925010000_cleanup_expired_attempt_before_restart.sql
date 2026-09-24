-- An expired, unsubmitted attempt is no longer resumable and must not keep the
-- one_open_attempt_per_variant index from allowing a new attempt to start.

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

  delete from public.attempts
  where user_id = auth.uid()
    and variant_id = target_variant
    and submitted_at is null
    and expires_at <= now();

  select id into attempt
  from public.attempts
  where user_id = auth.uid()
    and variant_id = target_variant
    and submitted_at is null
    and expires_at > now()
  order by started_at desc
  limit 1;

  if attempt is null then
    insert into public.attempts (user_id, variant_id, expires_at)
    values (auth.uid(), target_variant, now() + make_interval(secs => variant_duration))
    returning id into attempt;
  end if;

  return attempt;
end;
$$;
