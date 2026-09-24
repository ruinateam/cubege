# Supabase schema

`20260924000000_schema_baseline.sql` is the canonical schema snapshot of the
live project `ncclidrfaemzdefrzomv` as verified on 2026-09-24. It is a
bootstrap for an empty project, not an incremental migration for production.

It intentionally contains no exam prompts, answer keys, solutions, Storage
objects, profiles, attempts, or answers. Exam content is managed only in
Supabase and must never be committed.

## Applying changes

- **Empty project:** apply the baseline, configure Auth and the Twitch
  provider, then load approved content through the separate content process.
- **Live project:** never re-run the baseline. Apply only a new, reviewed
  migration created after this snapshot.
- **Future changes:** add one timestamped migration per reviewed schema change
  and update this baseline after it has been applied and verified in live
  Supabase.

The previous files were a partial, timestamp-mismatched reconstruction of live
history. They were merged into the current snapshot rather than retained as a
misleading migration chain.
