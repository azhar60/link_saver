# Link Saver — Build Plan

A personal Rails 8 app that saves URLs, fetches their content, and uses Gemini AI to generate summaries and tags. Built in small daily increments using Hotwire for interactivity.

## How to use this plan

1. Each day, pick the next unchecked task.
2. Open a terminal in the project folder and run `claude` (or your AI assistant).
3. Tell it: **"Read PLAN.md and complete the next unchecked task. Commit when done."**
4. Review the diff, then merge/push.
5. Check off the task here and commit the updated PLAN.md.

**Rules for the AI assistant:**
- Do ONE task per session. Do not skip ahead.
- After completing a task, write a clear commit message: `feat: <task name>` or `fix: <task name>`.
- Keep changes small. If a task feels too big, split it and ask the user which half to do.
- Run `rails test` (or relevant tests) before committing.
- Never commit `.env` or any secrets.
- Update PLAN.md to check off completed tasks and include it in the commit.

---

## Tech stack

- **Ruby on Rails 8** with Hotwire (Turbo + Stimulus, included by default)
- **Tailwind CSS** for styling
- **PostgreSQL** (local server already running on dev machine)
- **Solid Queue** for background jobs (Rails 8 default)
- **Solid Cable** for WebSockets / Turbo Streams (Rails 8 default)
- **Gemini API** (free tier — `gemini-2.5-flash-lite` model) for summaries and tags
- **HTTParty + Nokogiri** for fetching and parsing article pages

---

## Phase 1 — Foundation (Week 1)

Goal: a working Rails 8 app with Postgres where you can manually create a link record.

- [x] **Day 1 — Initialize the project**
  - Confirm Rails 8 is installed (`rails -v`); if not, `gem install rails`
  - Run `rails new link_saver --database=postgresql --css=tailwind`
  - Add gems to Gemfile: `httparty`, `nokogiri`, `dotenv-rails`
  - Run `bundle install`
  - Configure `config/database.yml` to use your local Postgres credentials (likely default `postgres` user, no password, or whatever is set up locally)
  - Run `rails db:create`
  - Initial commit: `chore: initialize Rails 8 app with Postgres and Tailwind`

- [x] **Day 2 — Generate the Link model**
  - Scaffold: `rails g scaffold Link url:string title:string summary:text tags:string status:string`
  - Add a default value to `status` in the migration (default: `"pending"`)
  - Run `rails db:migrate`
  - Add validation: `url` must be present and start with `http`
  - Add an enum: `enum :status, { pending: "pending", processing: "processing", ready: "ready", failed: "failed" }`
  - Commit: `feat: add Link model with scaffold`

- [x] **Day 3 — Clean up the scaffolded UI**
  - Update `app/views/links/index.html.erb` to show links as cards (title, summary preview, tags)
  - Style with Tailwind utility classes
  - Use a clean grid layout (responsive: 1 column mobile, 2-3 columns desktop)
  - Commit: `style: card layout for links index`

- [x] **Day 4 — Set up environment variables**
  - Create `.env` file (verify it's in `.gitignore`)
  - Add `GEMINI_API_KEY=` placeholder with instructions in README
  - Get a free key from aistudio.google.com and store locally (do NOT commit)
  - Add a README section explaining setup steps
  - Commit: `chore: add dotenv config and update README`

---

## Phase 2 — Fetch & Parse (Week 2)

Goal: when you paste a URL, the app fetches the page and extracts its title and main text.

- [x] **Day 5 — Create a PageFetcher service**
  - Create `app/services/page_fetcher.rb`
  - Method: `PageFetcher.fetch(url)` returns `{ title:, content: }` or `nil` on error
  - Use HTTParty with 10-second timeout, follow redirects
  - Use Nokogiri to extract `<title>` and strip `<script>`, `<style>`, `<nav>`, `<footer>`
  - Truncate content to 6000 chars
  - Commit: `feat: add PageFetcher service`

- [x] **Day 6 — Wire fetching into the create action**
  - In `LinksController#create`, call `PageFetcher.fetch(url)` before save
  - Populate `title` from the fetched data
  - Handle fetch failure gracefully (save with default title, flash a warning)
  - Commit: `feat: auto-populate title from URL on create`

- [ ] **Day 7 — Write a test for PageFetcher**
  - Use WebMock to mock HTTP responses
  - Test: valid URL returns title and content, bad URL returns nil
  - Commit: `test: add PageFetcher specs`

---

## Phase 3 — AI Summarization (Week 3)

Goal: the app calls Gemini to generate a summary and tags for each link.

- [ ] **Day 8 — Create a GeminiClient service**
  - Create `app/services/gemini_client.rb`
  - Method: `GeminiClient.summarize(text)` returns `{ summary:, tags: [] }`
  - Use the endpoint: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent`
  - Prompt: "Summarize in 2-3 sentences. Then list 3-5 tags. Return JSON: {summary, tags}"
  - Parse the JSON from response, strip any markdown fences
  - Commit: `feat: add GeminiClient service`

- [ ] **Day 9 — Wire AI into the create flow (synchronous for now)**
  - In `LinksController#create`, after fetching the page, call `GeminiClient.summarize(content)`
  - Save `summary` and `tags` (join array with commas) on the Link
  - Set status to `ready` on success, `failed` on error
  - Commit: `feat: generate AI summary and tags on link create`

- [ ] **Day 10 — Handle AI failures gracefully**
  - Wrap GeminiClient calls in error handling
  - If API fails, save the link with status `failed`, show a "Retry summary" button
  - Commit: `feat: graceful handling of AI failures`

- [ ] **Day 11 — Add a "Regenerate summary" button**
  - Add `regenerate` action on LinksController (POST route)
  - Button on the link show page
  - Commit: `feat: add regenerate summary button`

---

## Phase 4 — Polish & Search (Week 4)

Goal: actually useful for daily use — search, tag filtering, better UI.

- [ ] **Day 12 — Display tags as clickable chips**
- [ ] **Day 13 — Filter links by tag**
- [ ] **Day 14 — Add full-text search**
- [ ] **Day 15 — Add pagination**

---

## Phase 5 — Background Jobs with Hotwire (Week 5)

- [ ] **Day 16 — Verify Solid Queue is set up**
- [ ] **Day 17 — Move AI processing to a job**
- [ ] **Day 18 — Live updates with Turbo Streams**
- [ ] **Day 19 — Stimulus controller for the create form**

---

## Phase 6 — Convenience Features (Week 6+)

- [ ] Bookmarklet
- [ ] Browser extension
- [ ] Weekly digest email
- [ ] Reading time estimate
- [ ] Archive read links
- [ ] Export to JSON/CSV
- [ ] Dark mode toggle
- [ ] Postgres full-text search (pg_search)
- [ ] Deploy (Fly.io / Render)
- [ ] Public sharing
- [ ] Related links
- [ ] Auth
