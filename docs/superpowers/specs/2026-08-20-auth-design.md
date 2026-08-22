# Auth — single-owner sign-in

**Date:** 2026-08-20
**Status:** approved; revised after independent review
**Plan item:** PLAN.md → Phase 6 → Auth

## Goal

Put a sign-in gate in front of Link Saver so exactly one owner can reach it. This is the
last blocker before the app can be deployed: today every route is world-writable, so
publishing it would hand anyone who finds the URL the ability to create, edit, and
destroy links.

Auth is also an upstream dependency for two other open Phase 6 items — public sharing
needs an owner to share *from*, and the weekly digest needs an addressee.

## Decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Scope | Single owner, no signup | Personal app. Keeps `Link` untouched; multi-user later costs one migration plus a backfill. |
| Mechanism | Rails 8 `generate authentication`, trimmed | Gives db-backed sessions, `Current` attributes, and return-to handling the bookmarklet flow needs anyway. |
| Bootstrap | `db/seeds.rb` from `.env`, skipped when unset | Matches the existing dotenv convention (`GEMINI_API_KEY`). Skipping rather than raising keeps `bin/ci` green — see Bootstrap. |
| Public surface | Sign-in and `/up` only | Simplest rule to reason about; sharing can open specific routes deliberately later. |
| Password reset | Dropped | No SMTP is configured. Recovery is re-seeding with a new password. |
| Cable connection | Keep the generated one | It gates `/cable`, which is wide open today. See The gate. |

## Data model

Two new tables, both generated (`email_address:string!:uniq password_digest:string!` and
`user:references ip_address:string user_agent:string`):

- `users` — `email_address` (unique index, normalized to stripped lowercase on write),
  `password_digest`, timestamps.
- `sessions` — `user_id` FK, `ip_address`, `user_agent`, timestamps. Rows are the session
  of record, so revoking access means deleting rows.

`bcrypt` is uncommented in the Gemfile. It is **not** currently in `Gemfile.lock` (only
`bcrypt_pbkdf`, pulled in by kamal), so this forces a Bundler re-resolve — the generator
shells out to `bundle install` itself. The updated lockfile must be committed.

**`links` gains no `user_id`.** With a single owner, ownership is implied. `Link` and
every query built on it — `search`, `tagged_with`, `related`, `active`/`archived`, the
export, `ProcessLinkJob` — are unchanged. This is the decision that keeps the feature
small.

`User` gets two validations beyond `has_secure_password`:

```ruby
validate :only_one_owner, on: :create
validates :password, length: { minimum: 12 }, allow_nil: true

def only_one_owner
  errors.add(:base, "only one owner account is allowed") if User.exists?
end
```

The first makes single-owner a real invariant rather than a consequence of the missing
signup route. The second is cheap defense-in-depth: this one credential becomes the sole
gate on an internet-facing app, and until the rate limiter is durable (see below) a weak
password is the most realistic path to compromise. `allow_nil` preserves
`has_secure_password`'s "nil password means no change" semantics on update.

## Bootstrap

`db/seeds.rb` upserts the one owner from `OWNER_EMAIL` and `OWNER_PASSWORD`:

```ruby
if ENV["OWNER_EMAIL"].present? && ENV["OWNER_PASSWORD"].present?
  owner = User.first || User.new
  owner.email_address = ENV["OWNER_EMAIL"]
  owner.password      = ENV["OWNER_PASSWORD"]
  owner.save!
else
  Rails.logger.warn "[seeds] OWNER_EMAIL/OWNER_PASSWORD unset — no owner created; sign-in will be impossible until seeded."
  puts "[seeds] skipped owner creation: OWNER_EMAIL/OWNER_PASSWORD unset"
end
```

Idempotent by construction. Re-seeding rotates the password; changing `OWNER_EMAIL`
renames the existing owner rather than creating a second account, which keeps seeding
consistent with `only_one_owner`.

**It skips rather than raises, and that is deliberate.** Two existing entry points run
seeds: `bin/setup` calls `bin/rails db:prepare` (which seeds a freshly created database),
and `config/ci.rb` runs both `bin/setup --skip-server` and
`env RAILS_ENV=test bin/rails db:seed:replant`. Since `.env` is gitignored, any fresh
clone or CI runner has no `OWNER_*` vars, so an `ENV.fetch` would turn `bin/ci` red and
break first-run setup. Skipping with a loud warning keeps both green; the cost is that a
misconfigured deploy comes up with no owner and an unusable sign-in page, which the
warning is there to catch.

`.env` and the README gain the two keys, documented by name. Values stay local — `.env`
is gitignored and must never be committed.

## The gate

The generated `Authentication` concern is injected into `ApplicationController`
(`include Authentication`) with `before_action :require_authentication`, backed by
`Current.session` / `Current.user` and a signed, permanent, httponly `session_id` cookie.
Signing in once persists, which is the right trade for a personal app.

`SessionsController#new` and `#create` are the only `allow_unauthenticated_access`
exceptions. `#destroy` deletes the session row and clears the cookie.

Gate coverage was enumerated route by route: `LinksController`,
`Links::ArchivesController`, and `BookmarkletController` all inherit
`ApplicationController`, so the gate reaches every action including the `.json` and
`.csv` formats and `/links/export`. No engines are mounted.

- **`/up` needs no exception.** `Rails::HealthController` descends from
  `ActionController::Base`, so it never sees the gate. Load balancers keep working.
- **The bookmarklet and extension keep working.** Both build a plain GET
  `/links/new?link[url]=…&link[title]=…` and open it in a real tab, so the concern's
  `session[:return_to_after_authenticating] = request.url` captures the whole thing and
  `after_authentication_url` replays it. Signed out, you land on sign-in and then return
  to the prefilled form.

### Action Cable is gated too — and that is new behavior

The generator also emits `app/channels/application_cable/connection.rb` (it is guarded by
`if defined?(ActionCable::Engine)`, and this app loads `require "rails/all"`). Its body is
`set_current_user || reject_unauthorized_connection`, resolving `Session` from the signed
cookie.

This matters because `app/channels/` does not exist today, so Action Cable currently
falls back to `ActionCable::Connection::Base` and **accepts every `/cable` connection**.
The moment that file lands, cable connections require a valid session.

**Decision: keep it.** Gating `/cable` is correct under auth, and nothing breaks —
`Turbo::StreamsChannel` descends from `ActionCable::Channel::Base`, so no
`ApplicationCable::Channel` is required. Both `turbo_stream_from` call sites
(`links/index.html.erb:3` and `links/show.html.erb:3`) sit on pages that now require a
session, so subscribing already implies being signed in.

Note for the implementer: the integration tests never open a cable connection, so a
broken subscription would be invisible to the suite. Verify live updates by hand once.

### Required: two route changes

`after_authentication_url` falls back to `root_url`, and `config/routes.rb` defines **no
root route** — the scaffolded `root "posts#index"` is still commented out. Signing in
directly from `/session/new` would raise. Add:

```ruby
root "links#index"
```

This one is a prerequisite, not a nice-to-have.

Second, narrow the generated session route to the three actions the controller actually
defines, so a stray `GET /session` cannot reach a missing `show`:

```ruby
resource :session, only: %i[ new create destroy ]
```

### Rate limiting

Keep the generator's `rate_limit to: 10, within: 3.minutes, only: :create` as generated.
It reads `Rails.cache`:

- development — `:memory_store`, per process, so the effective limit is 10 × Puma workers.
- test — `:null_store`, whose `increment` returns `nil`, so the limiter no-ops and
  repeated `sign_in_as` calls across a run cannot trip it.
- production — `config.cache_store` is commented out, so Rails' default
  `[:file_store, "tmp/cache"]` applies: shared across workers on one host, but lost
  whenever the release or container is replaced.

**Making it durable is deliberately deferred to the Deploy plan item.** `solid_cache` is
in the Gemfile and `config/database.yml` already declares a production `cache:` database
with `migrations_paths: db/cache_migrate`, but the gem was never installed — no
`config/cache.yml`, no `db/cache_migrate`, no `cache_schema.rb`. Wiring it means running
`bin/rails solid_cache:install`, then creating and migrating that database. That is
deploy work for an app that is not yet deployed.

## Deploy prerequisites this feature creates

Auth is billed as the last blocker before deploy, so it must hand the Deploy item an
accurate list. Three things, none of them in scope here:

1. **Install solid_cache** and set `config.cache_store = :solid_cache_store`, or the
   sign-in rate limit resets on every release.
2. **Enable `config.force_ssl = true`** (or `assume_ssl` if TLS terminates upstream) —
   both are commented out in `config/environments/production.rb`. The permanent session
   cookie is set `httponly: true, same_site: :lax` but **not** `secure`, and it is
   `force_ssl` that marks cookies secure and adds HSTS. Without it the cookie can travel
   over plain HTTP.
3. **Know how to revoke access.** Re-seeding rotates `password_digest` but does **not**
   touch `Session` rows, and `resume_session` only checks the cookie against the row — so
   a stolen cookie survives a password change indefinitely. The actual revocation step is
   `Session.delete_all` (or deleting one row) from the console. There is deliberately no
   session-management UI, so this needs to be written down.

## UI

**Sign-in page** — one view at `app/views/sessions/new.html.erb`, replacing the generated
one: a centered card using the app's existing vocabulary (`glass-strong`, `btn-primary`,
`alert`, the `mist` palette, `gradient-cv` on the logo mark) so it reads as the same
product rather than a scaffold. Email and password, one submit button. No "remember me"
(the permanent cookie covers it), no signup link, and **no "Forgot password?" link** —
the generated view ends with `link_to "Forgot password?", new_password_path`, which would
raise once the passwords route is removed.

Also drop the generated view's `value: params[:email_address]` on the email field: a
failed sign-in **redirects** rather than re-renders, so that value is always blank.

**Nav** — `app/views/layouts/application.html.erb` always renders Bookmarklet / Archive /
New link. Wrap those in `if authenticated?` and add a sign-out `button_to`
(`DELETE /session`). Point the logo at `new_session_path` when unauthenticated, otherwise
the sign-in page's only visible control bounces back to sign-in via `links_path`.

The generated `#destroy` redirects with no message; add
`notice: "You have been signed out."` so the sign-out path says something.

**Flash consolidation** — the layout renders only `flash[:alert]`; `notice` is rendered
separately in `links/index.html.erb:6` and `links/show.html.erb:16`. The sign-in page
needs notices too, and a third copy is the wrong answer. Move `notice` into the layout
beside `alert` and delete the two duplicated blocks. This continues the unification
started in `ad53371`. Safe: nothing in `test/` references `notice` or `#notice`. Accepted
trade-off: the banner moves above `<main>`, a small visual shift on those two pages.

## Testing

`test_helper.rb` gains a `sign_in_as(user, password: "secret123")` helper mixed into
`ActionDispatch::IntegrationTest`, POSTing `email_address` and `password` to
`session_url`.

`test/fixtures/users.yml` must be **overwritten**, not merely created: the generator
writes two rows (`one:`, `two:`) whose digest is for the plaintext `"password"`. Left as
generated, `sign_in_as` fails on every request and the test database holds two owners
while `only_one_owner` forbids exactly that — so the "rejects a second record" test would
pass for the wrong reason. Replace it with one owner, and build the digest cheaply:

```yaml
owner:
  email_address: owner@example.com
  password_digest: <%= BCrypt::Password.create("secret123", cost: BCrypt::Engine::MIN_COST) %>
```

`min_cost` only applies to digests made *through* `has_secure_password`, so a bare
`BCrypt::Password.create` bakes in cost 12 and every `sign_in_as` would pay a full-cost
verify. `test/models/user_test.rb` is likewise a generated empty stub to be filled in.

The 7 existing tests in `links_controller_test.rb` assume open access and would fail on a
302; each gets `sign_in_as` in `setup`.

New coverage:

- a signed-out request to `/links` redirects to sign-in
- after signing in, the originally requested URL is replayed with bookmarklet params
  intact (this is the extension flow, so it earns a real test)
- a wrong password **redirects** to sign-in with `flash[:alert]` and starts no session —
  the generated controller redirects, so do not assert a re-render or
  `:unprocessable_entity`
- sign-out deletes the session row and clears the cookie
- `User` rejects a second record, and rejects a password under 12 characters

## Out of scope

No `user_id` on links and no per-user scoping. No password reset by email, no OAuth or
magic links, no API tokens for the JSON/export endpoints, no 2FA, no session-management
UI, no absolute session expiry. Deploy itself stays a separate plan item; public sharing
likewise — this feature only unblocks it.

## Known rough edges (accepted)

- **Cookie overflow on the return-to path.** `request_authentication` stores the full
  `request.url` in the 4KB `CookieStore`. The extension builds
  `/links/new?link[url]=<tab.url>&link[title]=<tab.title>`, so a very long URL plus title
  could raise `CookieOverflow` — a 500 on exactly the flow above. Storing
  `request.fullpath`, or skipping the stash past a length threshold, removes it if it ever
  bites.
- **`return_to` is stashed for any verb.** The 8.0.5 concern has no `request.get?` guard,
  so a POST made while signed out is replayed as a GET after sign-in. Harmless here.
- **Turbo Frame search form.** `links/index.html.erb` submits into
  `turbo_frame_tag "links_frame"`. If the session is gone when that fires, Turbo follows
  the 302, finds no matching frame, and blanks the frame with a console error instead of
  navigating to sign-in. Rare given the permanent cookie.
- **`/links.json` and `/links/export.json`** answer signed-out clients with a 302 to HTML
  sign-in rather than a 401. Consistent with "no API tokens" being out of scope.

## Files touched

**New** — `app/models/user.rb`, `app/models/session.rb`, `app/models/current.rb`,
`app/controllers/concerns/authentication.rb`, `app/controllers/sessions_controller.rb`,
`app/channels/application_cable/connection.rb`, `app/views/sessions/new.html.erb`,
`test/fixtures/users.yml`, `test/models/user_test.rb`,
`test/controllers/sessions_controller_test.rb`, two migrations.

**Edited** — `Gemfile` (uncomment bcrypt), `Gemfile.lock`, `db/schema.rb` (regenerated —
CI runs `db:test:prepare`, which loads schema, so an uncommitted schema means every test
fails on a missing `users` table), `config/routes.rb` (root route, narrowed
`resource :session`), `app/controllers/application_controller.rb`,
`app/views/layouts/application.html.erb`, `app/views/links/index.html.erb`,
`app/views/links/show.html.erb`, `db/seeds.rb`, `test/test_helper.rb`,
`test/controllers/links_controller_test.rb`, `.env`, `README.md`, `PLAN.md`.

**Deleted** — `app/controllers/passwords_controller.rb`, `app/mailers/passwords_mailer.rb`,
`app/views/passwords/new.html.erb`, `app/views/passwords/edit.html.erb`,
`app/views/passwords_mailer/reset.html.erb`, `app/views/passwords_mailer/reset.text.erb`,
`test/mailers/previews/passwords_mailer_preview.rb` (it calls
`PasswordsMailer.reset`, so leaving it makes `/rails/mailers` raise), and the
`resources :passwords, param: :token` route.

## Notes for the implementer

- The shell in this workspace resolves Ruby 3.0.0 while `.ruby-version` pins 3.3.0. Run
  `rvm use 3.3.0` **before** the generator, not just before `bin/rails` — the generator's
  `enable_bcrypt` step shells out to `bundle install`, so it needs the right Ruby and
  network access.
- Run the generator first, then trim. **Delete the passwords files, remove the
  `resources :passwords` route, and rewrite `app/views/sessions/new.html.erb` in the same
  step** — the generated sign-in view links to `new_password_path`, so any window between
  those changes leaves `/session/new` raising `NoMethodError`.
- Commit the regenerated `db/schema.rb` and `Gemfile.lock` alongside the migrations.
