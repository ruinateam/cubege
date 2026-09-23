# AGENTS.md — cubege

## Dev-сервер
- Пользователь сам держит `bun run dev` на `http://localhost:5173/`.
- НЕ запускать `bun run dev`, `vite`, `vite preview` — порт уже занят, свой сервер не поднимать.
- Для браузерной проверки использовать уже запущенный `http://localhost:5173/`.
- Билд для проверки: `bun run build`. Это компиляция, а не сервер, его можно.

## Git: только с согласия
- НЕ делать `git push` без явного согласия пользователя в этом диалоге.
- По умолчанию: менять файлы, показывать diff, ждать команды. Коммит — тоже только по просьбе.
- Причина: push в `main` триггерит Deploy to GitHub Pages (см. `.github/workflows/deploy.yml`); красные деплои не плодить, сайт сейчас оффлайн.
- Перед коммитом: `bun run build`, `bun audit`, `git diff --check`.
- Сообщения — Conventional Commits: `feat/fix/ops/docs/chore` (+ скоупы, напр. `feat(exam): ...`). Тип `ops` разрешён (commitlint).
- Формат строгий (проверяется в CI): subject — только строчные буквы (`feat(ui): ...`, без заглавных даже в именах), тело — строки не длиннее 100 символов, пустая строка между subject и телом.

## Стек и команды
- Bun 1.4.0 (lockfile v2), не npm/npx. Установка: `bun install --ignore-scripts`, в CI — `--frozen-lockfile`.
- Проверки: `bun run typecheck`, `bun run build`, `bun audit`.
- Shell — Windows pwsh.

## Supabase и контент — чего не делать
- Контент вариантов (формулировки, ключи, решения) живёт ТОЛЬКО в Supabase, никогда не коммитить в репозиторий.
- Gitignored и запрещены к коммиту: `source/cubege.pdf`, `source/cubege-test-final-v4.json`, `.env.local`. Ключи ответов не должны попадать в клиентский bundle — проверка только через RPC (`submit_attempt`, `grade_answer`).
- `supabase/migrations/20260923_init.sql` — черновик, НЕ source of truth. Живая схема ушла вперёд через прямые миграции; файл не править как «текущую схему» без сверки с живой базой (ref `ncclidrfaemzdefrzomv`).
- Секреты: `.env.local` (локально) и Actions variables/secrets `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY`. Только publishable-ключ в `VITE_*`. Service role key — ни в код, ни в `.env`, ни в CI.
- Тестовые попытки/профили в базе без спроса не тереть и не плодить.

## Handoff
- `tasks/status.md` — актуальный handoff между сессиями; `tasks/plan.md`, `tasks/todo.md` — план. После значимых изменений обновлять `tasks/status.md`.
