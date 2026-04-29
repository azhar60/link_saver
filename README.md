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
```

### Required environment variables

The app reads these from `.env` (loaded automatically by `dotenv-rails`):

| Variable         | Required | Notes                                                             |
| ---------------- | -------- | ----------------------------------------------------------------- |
| `GEMINI_API_KEY` | yes      | Free key from https://aistudio.google.com/apikey. Never commit it. |

`.env` is gitignored — every developer creates their own.

## Running the app

```bash
bin/rails server     # http://localhost:3000/links
bin/jobs             # background worker (Solid Queue)
```

## Tests

```bash
bin/rails test
```

## Project plan

See [`PLAN.md`](PLAN.md) for the day-by-day build plan.
