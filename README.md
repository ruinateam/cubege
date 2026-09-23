# ЕГЭ по кубам

> Пробный ЕГЭ по Minecraft: 20 заданий, 120 минут, проверка кратких ответов и разбор результата.

[Открыть сайт](#) · [Сообщить об ошибке](../../issues)

## Что внутри

- **Пробный вариант 2026**: 15 заданий с кратким ответом и 5 развёрнутых.
- **Таймер и автосохранение**: черновик остаётся на устройстве, ответы — в Supabase.
- **Анонимный вход и Twitch OAuth**: можно начать сразу, затем привязать Twitch.
- **Профиль**: аватар, display name и статистика пройденных вариантов.
- **Без спойлеров**: ключи не попадают в клиентский bundle; их проверяет Supabase RPC после сдачи.
- **GitHub Pages**: статическая сборка публикуется GitHub Actions.

## Стек

| Слой | Инструменты |
| --- | --- |
| Frontend | Vue 3, TypeScript, Vite 8, Bun |
| Backend | Supabase Auth, Postgres, RLS, RPC |
| Авторизация | Anonymous Auth, Twitch OAuth |
| Deploy | GitHub Pages + GitHub Actions |

## Быстрый старт

```bash
bun install --ignore-scripts
copy .env.example .env.local
bun run dev
```

Создайте `.env.local`:

```dotenv
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_replace_me
VITE_BASE_PATH=/
```

Проверка production-сборки:

```bash
bun run build
bun audit
```

## Настройка Supabase

1. Создайте проект Supabase и включите **Anonymous Sign-Ins**.
2. Включите **Twitch** в Authentication → Providers, добавив Client ID и Client Secret из Twitch Developer Console.
3. Выполните миграции из `supabase/migrations/`.
4. В **Authentication → URL Configuration** укажите production Site URL вашего сайта.
5. Добавьте Redirect URLs:
   - `https://<your-domain>/`
   - `http://localhost:5173/`
6. В Twitch Developer Console добавьте callback:
   `https://<project-ref>.supabase.co/auth/v1/callback`

`VITE_SUPABASE_PUBLISHABLE_KEY` допустимо передавать клиенту. Никогда не добавляйте service role key в `.env.local`, исходники или GitHub Actions variables.

## Контент вариантов

Формулировки, варианты ответов, ключи и решения живут только в Supabase (`questions`, `exam_variants`) и никогда не коммитятся в репозиторий. Сайт загружает их через RPC `list_variants` / `variant_questions`; ответы проверяет `submit_attempt` по шкале `exam_variants.score_scale`. Новый вариант добавляется строками в этих таблицах — код менять не нужно.

Краткие ответы проверяются автоматически, развёрнутые — вручную: после назначения роли `admin` (SQL выше) в аккаунт-меню появляется пункт «Проверка» со списком сданных попыток, эталонами и выставлением баллов через `grade_answer` с автоматическим пересчётом.

## Деплой и домен

Workflow `.github/workflows/deploy.yml` публикует сайт после push в `main`.

Для собственного домена:

1. В DNS создайте CNAME поддомена на `<your-github-login>.github.io`.
2. В GitHub: **Settings → Pages → Custom domain** → ваш домен.
3. После проверки DNS включите **Enforce HTTPS**.

Файл `public/CNAME` автоматически попадает в Pages-артефакт.

## Структура

```text
src/
├── assets/         # вендорные SVG (логотип)
├── components/     # UI-компоненты
├── composables/    # auth, попытка, профиль и список вариантов
├── data/           # типы вопросов и шкала баллов по умолчанию
└── lib/            # Supabase-клиент и API
supabase/migrations/ # схема, RLS и RPC
```

## Коммиты

Используем [Conventional Commits](https://www.conventionalcommits.org/):

```text
feat(exam): add answer autosave
fix(auth): restore Twitch session
docs: update Supabase setup
```

Проверка commit message выполняется в GitHub Actions. Перед коммитом можно проверить сообщение вручную:

```bash
echo "feat(exam): add answer autosave" | bunx commitlint
```
