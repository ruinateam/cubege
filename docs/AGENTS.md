# Проектные правила

## Запуск и проверки

- Не запускать `bun run dev`, `vite` или `vite preview`: dev-сервер уже ведёт пользователь.
- Для проверки использовать существующий `http://localhost:5173/`.
- Использовать Bun 1.4.0: `bun install --ignore-scripts`, `bun run typecheck`,
  `bun run build`, `bun audit`.

## Git

- Коммит и `git push` — только по явной просьбе пользователя.
- Перед коммитом выполнить `bun run build`, `bun audit` и `git diff --check`.
- Сообщения — Conventional Commits, subject в нижнем регистре.

## Supabase и данные

- Экзаменационный контент, ключи и решения хранятся только в Supabase и не
  коммитятся.
- Не добавлять service role key в код, переменные клиента или CI.
- Не создавать и не удалять тестовые профили или попытки без запроса.
- `supabase/migrations/20260924000000_schema_baseline.sql` — snapshot для
  пустой базы, не миграция для повторного применения в live-проекте.

## Handoff

- После значимых изменений обновлять `tasks/status.md`.
