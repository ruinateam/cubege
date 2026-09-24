-- A submitted attempt is already closed, so its owner may review every short-answer
-- key, including questions they left blank. This keeps the immediate and historical
-- result feeds consistent.

create or replace function public.attempt_results(target_attempt uuid)
returns table(question_position smallint, is_correct boolean, correct_answer text, solution text, awarded_points smallint, max_points smallint, graded boolean)
language sql
security definer
set search_path = public
as $$
  select q.position,
    case when q.kind = 'short' then lower(regexp_replace(coalesce(aa.value, ''), '\s', '', 'g')) = lower(q.answer) else null end,
    case when q.kind = 'short' then q.answer else null end,
    q.solution,
    coalesce(aa.awarded_points, 0),
    q.points,
    aa.graded_at is not null
  from public.attempts a
  join public.questions q on q.variant_id = a.variant_id
  left join public.attempt_answers aa on aa.attempt_id = a.id and aa.position = q.position
  where a.id = target_attempt and a.user_id = auth.uid() and a.submitted_at is not null
  order by q.position;
$$;

create or replace function public.attempt_detail(target_attempt uuid)
returns table(
  attempt_id uuid,
  variant_slug text,
  variant_title text,
  submitted_at timestamptz,
  primary_score smallint,
  secondary_score smallint,
  score_scale smallint[],
  question_position smallint,
  kind text,
  points smallint,
  prompt text,
  options jsonb,
  image_path text,
  value text,
  is_correct boolean,
  correct_answer text,
  solution text,
  awarded_points smallint,
  graded boolean
)
language sql
security definer
set search_path = public
as $$
  select
    a.id,
    v.slug,
    v.title,
    a.submitted_at,
    a.primary_score,
    a.secondary_score,
    v.score_scale,
    q.position,
    q.kind::text,
    q.points,
    q.prompt,
    q.options,
    q.image_path,
    coalesce(aa.value, ''),
    case when q.kind = 'short' then lower(regexp_replace(coalesce(aa.value, ''), '\s', '', 'g')) = lower(q.answer) else null end,
    case when q.kind = 'short' then q.answer else null end,
    q.solution,
    coalesce(aa.awarded_points, 0),
    aa.graded_at is not null
  from public.attempts a
  join public.exam_variants v on v.id = a.variant_id
  join public.questions q on q.variant_id = a.variant_id
  left join public.attempt_answers aa on aa.attempt_id = a.id and aa.position = q.position
  where a.id = target_attempt
    and a.user_id = auth.uid()
    and a.submitted_at is not null
  order by q.position;
$$;
