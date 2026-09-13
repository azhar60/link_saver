# Link Saver

A personal Rails 8 app that saves URLs, fetches their content, and uses Gemini AI to generate summaries and tags. Built with Hotwire (Turbo + Stimulus) and Tailwind CSS.

## Tech stack

- Ruby 3.3.0
- Rails 8.0 with Hotwire
- PostgreSQL
- Tailwind CSS
- Solid Queue (background jobs) and Solid Cable (WebSockets / Turbo Streams)
- Gemini API (`gemini-2.5-flash-lite`) for summaries and tags
- HTTParty + Nokogiri for fetching and parsing pages

## Prerequisites

- Ruby 3.3.0 (the repo pins this in `.ruby-version`)
- PostgreSQL running locally (default user/socket — no password configured)
- A free Gemini API key — get one at https://aistudio.google.com/apikey

## Setup

```bash
# 1. Install dependencies
bundle install

# 2. Create your local .env file
#    Add a line: GEMINI_API_KEY=<your-key-from-aistudio.google.com>
#    .env is gitignored — never commit it.

# 3. Create and migrate the databases
bin/rails db:create db:migrate

# 4. Create the owner account from OWNER_EMAIL / OWNER_PASSWORD
bin/rails db:seed
```

The app has exactly one account and no signup page. `bin/rails db:seed` creates the owner,
and running it again rotates the password to whatever `.env` currently holds. If the two
`OWNER_*` variables are unset, seeding skips with a warning and sign-in is impossible.

### Required environment variables

The app reads these from `.env` (loaded automatically by `dotenv-rails`):

| Variable          | Required | Notes                                                                     |
| ----------------- | -------- | ------------------------------------------------------------------------- |
| `GEMINI_API_KEY`  | yes      | Free key from https://aistudio.google.com/apikey. Never commit it.         |
| `OWNER_EMAIL`     | yes      | The single account that can sign in. Applied by `bin/rails db:seed`.       |
| `OWNER_PASSWORD`  | yes      | At least 12 characters. Re-seeding rotates it. Never commit it.           |

`.env` is gitignored — every developer creates their own.

## Running the app

```bash
bin/rails server     # http://localhost:3000/links
bin/jobs             # background worker (Solid Queue)
```

## Before deploying

The app is gated but not yet hardened for the public internet. Three things to do first:

1. **Wire a durable cache store.** `solid_cache` is in the Gemfile and `config/database.yml`
   already declares a production `cache:` database, but the gem was never installed. Run
   `bin/rails solid_cache:install`, create and migrate that database, and set
   `config.cache_store = :solid_cache_store`. Until then the sign-in rate limit
   (10 attempts / 3 minutes) lives in `tmp/cache` and resets on every release.
2. **Enable TLS.** Set `config.force_ssl = true` in `config/environments/production.rb`
   (or `assume_ssl` if TLS terminates upstream). The session cookie is `httponly` and
   `same_site: :lax` but not `secure` without it, so it can travel over plain HTTP.
3. **Know how to revoke access.** Re-seeding rotates the password but does *not* invalidate
   existing sessions — `resume_session` only checks the cookie against the `sessions` row.
   To cut off a stolen cookie, run `Session.delete_all` from the console. There is
   deliberately no session-management UI.

One accepted rough edge: the post-sign-in redirect stores the full requested URL in the
4KB cookie session, so a very long page URL and title arriving from the browser extension
can raise `CookieOverflow`. If that ever happens, store `request.fullpath` instead of
`request.url` in `Authentication#request_authentication`, or skip the stash past a length
threshold.

## Tests

```bash
bin/rails test
```

## Saving from anywhere

- **Bookmarklet** — visit `/bookmarklet` in the running app, drag the button to your bookmarks bar.
- **Browser extension** — `browser_extension/` is a Manifest V3 extension for Chrome / Edge / Brave. Load unpacked from `chrome://extensions`. See [`browser_extension/README.md`](browser_extension/README.md).

## Project plan

See [`PLAN.md`](PLAN.md) for the day-by-day build plan.
