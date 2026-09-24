-- Grading must work even when a long answer row was never saved (e.g. "No answer").
-- attempt_long_answers already lists such questions via LEFT JOIN, so grade_answer
-- has to upsert instead of raising "Answer not found".

create or replace function public.grade_answer(target_attempt uuid, target_position smallint, awarded smallint)
returns void
language plpgsql
security definer
set search_path = public
as $function$
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

  insert into public.attempt_answers (attempt_id, position, value, awarded_points, graded_by, graded_at)
  values (target_attempt, target_position, '', awarded, auth.uid(), now())
  on conflict (attempt_id, position) do update
    set awarded_points = excluded.awarded_points,
        graded_by = excluded.graded_by,
        graded_at = excluded.graded_at;

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
