-- In questions where a player chooses several numbered statements, the set of
-- selected numbers matters, not their order. Matching tasks still require order.

create or replace function public.short_answer_is_correct(question_options jsonb, expected_answer text, submitted_answer text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case
    when regexp_replace(coalesce(submitted_answer, ''), '\s', '', 'g') ~ '^\d+$'
      and regexp_replace(coalesce(expected_answer, ''), '\s', '', 'g') ~ '^\d+$'
      and not exists (
        select 1
        from jsonb_array_elements_text(coalesce(question_options, '[]'::jsonb)) as option(value)
        where value ~ '^\s*[А-ЯЁ]\)'
      )
    then (
      select string_agg(value, '' order by value)
      from regexp_split_to_table(regexp_replace(coalesce(submitted_answer, ''), '\s', '', 'g'), '') as digit(value)
    ) = (
      select string_agg(value, '' order by value)
      from regexp_split_to_table(regexp_replace(coalesce(expected_answer, ''), '\s', '', 'g'), '') as digit(value)
    )
    else lower(regexp_replace(coalesce(submitted_answer, ''), '\s', '', 'g')) = lower(coalesce(expected_answer, ''))
  end;
$$;

create or replace function public.attempt_results(target_attempt uuid)
returns table(question_position smallint, is_correct boolean, correct_answer text, solution text, awarded_points smallint, max_points smallint, graded boolean)
language sql
security definer
set search_path = public
as $$
  select q.position,
    case when q.kind = 'short' then public.short_answer_is_correct(q.options, q.answer, aa.value) else null end,
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
    a.variant_id,
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
    case when q.kind = 'short' then public.short_answer_is_correct(q.options, q.answer, aa.value) else null end,
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

create or replace function public.submit_attempt(target_attempt uuid)
returns table(primary_score smallint, secondary_score smallint)
language plpgsql
security definer
set search_path = public
as $$
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
  select (
    coalesce(sum(q.points) filter (where q.kind = 'short' and public.short_answer_is_correct(q.options, q.answer, aa.value)), 0)
    + coalesce(sum(aa.awarded_points) filter (where q.kind = 'long'), 0)
  )::smallint
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
end;
$$;

-- Correct previously submitted scores according to the same comparison rule.
with recalculated_scores as (
  select
    a.id,
    (
      coalesce(sum(q.points) filter (where q.kind = 'short' and public.short_answer_is_correct(q.options, q.answer, aa.value)), 0)
      + coalesce(sum(aa.awarded_points) filter (where q.kind = 'long'), 0)
    )::smallint as primary_score
  from public.attempts a
  join public.questions q on q.variant_id = a.variant_id
  left join public.attempt_answers aa on aa.attempt_id = a.id and aa.position = q.position
  where a.submitted_at is not null
  group by a.id, a.variant_id
)
update public.attempts a
set primary_score = scores.primary_score,
    secondary_score = variants.score_scale[least(scores.primary_score + 1, array_length(variants.score_scale, 1))]
from recalculated_scores scores
join public.exam_variants variants on variants.id = scores.variant_id
where a.id = scores.id;
