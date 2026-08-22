# Single-Owner Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a sign-in gate in front of Link Saver so exactly one owner can reach it, unblocking deploy.

**Architecture:** Rails 8's built-in `generate authentication` (db-backed `Session` rows, `Current` attributes, signed permanent cookie), trimmed to a single owner with no signup and no password reset. The owner is seeded from `.env`. `Link` is untouched — no `user_id`, no per-user scoping — so every existing query, job, and export keeps working.

**Tech Stack:** Rails 8.0.5, Ruby 3.3.0, PostgreSQL, Minitest, bcrypt, Hotwire (Turbo + Stimulus), Tailwind.

**Spec:** `docs/superpowers/specs/2026-08-20-auth-design.md` — read it before starting. It records the decisions and the verified generator behavior this plan depends on.

---

## Before you start

**Ruby version.** This workspace's default shell resolves Ruby 3.0.0; the project pins 3.3.0. Run once per terminal session:

```bash
source ~/.rvm/scripts/rvm && rvm use 3.3.0
```

If your shell does **not** persist state between commands (agent tool calls), prefix every command below with `source ~/.rvm/scripts/rvm && rvm use 3.3.0 && `.

**Baseline (verified 2026-08-22):** `bin/rails test` → 12 runs, 26 assertions, 0 failures. The suite runs single-process (parallelization threshold is 50), so parallel-worker concerns do not apply at this size.

**The dev database holds 42 real links.** Migrations only add tables; never run `db:seed:replant` or `db:reset` in development.

**Never commit `.env`.** Task 6 adds keys to it; the file is gitignored and must stay untracked.

### Convention deviations (deliberate, do not "fix")

This project diverges from three loaded Rails convention skills. Each is intentional:

| Convention | This project | Why |
| --- | --- | --- |
| Pundit `authorize` in every action | No Pundit, no policies | Single owner. The session gate *is* the authorization model; per-user policies would authorize one user against their own data. Adding Pundit contradicts the approved spec. |
| RSpec in `spec/` | Minitest in `test/` | Project standard. Every convention about test *structure* still applies; only the framework differs. |
| ViewComponents, no `app/helpers/` | Plain ERB + existing `app/helpers/` | No ViewComponent gem. The sign-in view is static markup with no presentation logic, so nothing needs extracting. |

Aligned as-is: `Session` is a state record (presence of the row *is* the state), the generated migrations index their foreign key via `t.references`, and sign-out is a `button_to` — Turbo handles it, so no Stimulus controller is needed.

---

## Task 1: Branch and preflight

**Files:** none (verification only)

- [ ] **Step 1: Confirm a clean tree**
Run: `git status --porcelain`
Expected: empty output. Stop and resolve if not.

- [ ] **Step 2: Create the feature branch**
```bash
git checkout -b auth
```

- [ ] **Step 3: Verify the baseline is green**
Run: `bin/rails test`
Expected: `12 runs, 26 assertions, 0 failures, 0 errors, 0 skips`

---

## Task 2: The failing gate test

Write the test that proves the app is currently wide open, before anything exists to close it.

**Files:**
- Create: `test/controllers/authentication_test.rb`

- [ ] **Step 1: Write the failing test**
Create `test/controllers/authentication_test.rb` with an `ActionDispatch::IntegrationTest` asserting that a signed-out `GET /links` redirects to `/session/new`.

Give it its own file deliberately: `LinksControllerTest` gains a signing-in `setup` block in Task 4, which would defeat a signed-out test living there.

- [ ] **Step 2: Run it and watch it fail**
Run: `bin/rails test test/controllers/authentication_test.rb`
Expected: FAIL — the response is `200 OK`, not a redirect. (`new_session_path` does not exist yet, so this may instead fail with `NameError: undefined local variable or method 'new_session_path'`. Either failure is the correct RED state; assert against the literal path `"/session/new"` to get the clearer message.)

- [ ] **Step 3: Commit the red test**
```bash
git add test/controllers/authentication_test.rb
git commit -m "test: assert links index requires sign in (currently failing)"
```

---

## Task 3: Run the generator and trim it to shape

The generator emits password-reset machinery this app cannot use (no SMTP). Deleting it and rewriting the sign-in view happen in the **same commit** — the generated view links to `new_password_path`, so any intermediate state leaves `/session/new` raising `NoMethodError`.

**Files:**
- Create: `app/models/user.rb`, `app/models/session.rb`, `app/models/current.rb`, `app/controllers/concerns/authentication.rb`, `app/controllers/sessions_controller.rb`, `app/channels/application_cable/connection.rb`, `app/views/sessions/new.html.erb`, `test/fixtures/users.yml`, `test/models/user_test.rb`, two migrations
- Modify: `Gemfile`, `Gemfile.lock`, `config/routes.rb`, `app/controllers/application_controller.rb`, `db/schema.rb`
- Delete: `app/controllers/passwords_controller.rb`, `app/mailers/passwords_mailer.rb`, `app/views/passwords/new.html.erb`, `app/views/passwords/edit.html.erb`, `app/views/passwords_mailer/reset.html.erb`, `app/views/passwords_mailer/reset.text.erb`, `test/mailers/previews/passwords_mailer_preview.rb`

- [ ] **Step 1: Run the generator**
Requires network — it shells out to `bundle install` to add bcrypt (currently absent from `Gemfile.lock`).
```bash
bin/rails generate authentication
```
Expected: creates the files above, uncomments `gem "bcrypt"`, injects `include Authentication` into `ApplicationController`, and adds two routes.

- [ ] **Step 2: Delete the password-reset machinery**
```bash
rm app/controllers/passwords_controller.rb \
   app/mailers/passwords_mailer.rb \
   app/views/passwords_mailer/reset.html.erb \
   app/views/passwords_mailer/reset.text.erb \
   test/mailers/previews/passwords_mailer_preview.rb
rm -rf app/views/passwords app/views/passwords_mailer
```

- [ ] **Step 3: Fix the routes**
In `config/routes.rb`: delete the generated `resources :passwords, param: :token` line, narrow `resource :session` to `resource :session, only: %i[ new create destroy ]`, and add `root "links#index"`.

The root route is **required**, not cosmetic: `after_authentication_url` falls back to `root_url`, and this app has never defined one.

- [ ] **Step 4: Strip the dead link from the generated sign-in view**
Remove the trailing `<%= link_to "Forgot password?", new_password_path %>` line from `app/views/sessions/new.html.erb`, and remove `value: params[:email_address]` from the email field — a failed sign-in redirects rather than re-renders, so it is always blank. Leave the rest of the generated markup alone; Task 8 restyles it.

The generated view also renders its own `flash[:alert]` div while the layout renders one, so a failed sign-in shows the banner twice between here and Task 8. Expected, and it disappears when Task 8 replaces the markup.

- [ ] **Step 5: Run the migrations**
```bash
bin/rails db:migrate
```
Expected: creates `users` and `sessions`. Confirm `db/schema.rb` now contains both tables and that `sessions` has an index on `user_id` (`t.references` adds it).

- [ ] **Step 6: Verify the migrations roll back cleanly**
```bash
bin/rails db:rollback:primary STEP=2 && bin/rails db:migrate
```
Note the `:primary` — this is a multi-database app (primary + queue), so plain `db:rollback` aborts with "you must run the namespaced task with a VERSION" and reverts nothing.

Expected: `CreateSessions: reverted`, `CreateUsers: reverted`, then both re-applied, with `db/schema.rb` unchanged afterward. **Do not skip**, and read the output rather than the exit status — an irreversible migration is found now or in production.

- [ ] **Step 7: Run the tests**
Run: `bin/rails test`
Expected: the Task 2 gate test now **passes**, and the 7 pre-existing `LinksControllerTest` tests now **fail** with 302 redirects. This is the expected intermediate state — Task 4 fixes it.

- [ ] **Step 8: Commit**
```bash
git add -A
git commit -m "feat: add Rails 8 authentication, trimmed to single owner"
```
Confirm `Gemfile.lock` and `db/schema.rb` are both in the commit — CI runs `db:test:prepare`, which loads schema, so an uncommitted `schema.rb` fails every test.

---

## Task 4: Repair the test harness

The generated `users.yml` ships **two** rows digested for the plaintext `"password"`. Left alone it breaks sign-in helpers and contradicts the single-owner validation added in Task 5.

**Files:**
- Modify: `test/fixtures/users.yml`, `test/test_helper.rb`, `test/controllers/links_controller_test.rb`

- [ ] **Step 1: Replace the fixture with one owner**
Overwrite `test/fixtures/users.yml` entirely:
```yaml
owner:
  email_address: owner@example.com
  password_digest: <%= BCrypt::Password.create("secret123", cost: BCrypt::Engine::MIN_COST) %>
```
`MIN_COST` matters: `min_cost` only applies to digests created *through* `has_secure_password`, so a bare `BCrypt::Password.create` bakes in cost 12 and every sign-in in the suite pays a full-cost verify.

- [ ] **Step 2: Add the sign-in helper**
In `test/test_helper.rb`, add a `sign_in_as(user, password: "secret123")` helper that POSTs `email_address` and `password` to `session_url`. Mix it into `ActionDispatch::IntegrationTest` only — it needs request helpers that `ActiveSupport::TestCase` does not have.

- [ ] **Step 3: Sign in for the existing tests**
Add `sign_in_as(users(:owner))` to the `setup` block in `test/controllers/links_controller_test.rb`. The Task 2 signed-out test lives in its own file and is unaffected.

- [ ] **Step 4: Run the tests**
Run: `bin/rails test`
Expected: `13 runs, 0 failures, 0 errors` — all green again.

- [ ] **Step 5: Commit**
```bash
git add test/
git commit -m "test: sign in for gated link specs"
```

---

## Task 5: User validations

**Files:**
- Modify: `app/models/user.rb`
- Test: `test/models/user_test.rb`

- [ ] **Step 1: Write the failing tests**
In `test/models/user_test.rb`, add three tests. **Read the trap below before writing them.**

  1. *Single owner:* build `User.new(email_address: "second@example.com", password: "longenough12")`, call `valid?`, and assert `errors[:base]` includes the single-owner message. The fixture already supplies the first owner.
  2. *Password too short:* build a user with `password: "short"` — use exactly that, not `nil` or `""` — call `valid?`, and assert **`errors[:password]` is not empty**. A blank password would make `has_secure_password`'s own digest-presence check add `:blank`, so the test would pass at RED and contradict Step 2.
  3. *Password long enough:* build a user with a 12+ character password, call `valid?`, and assert **`errors[:password]` is empty**.

**The trap:** `only_one_owner` runs `on: :create`, and `User.new(...).valid?` uses the `:create` context. Because `test/fixtures/users.yml` already holds an owner, `User.exists?` is true, so **every** newly built user is invalid no matter how long its password is. Assert on `errors[:password]` specifically — never on `valid?` — for tests 2 and 3.

If you find yourself weakening or removing `only_one_owner` to turn a test green, stop: that validation is the single-owner invariant the spec exists to enforce, and the test is wrong, not the model. (An equivalent alternative for tests 2 and 3 is to exercise length through the persisted `users(:owner)`, where the `:update` context skips `on: :create`.)

- [ ] **Step 2: Run and watch them fail**
Run: `bin/rails test test/models/user_test.rb`
Expected: **tests 1 and 2 fail.** Test 1 fails because `errors[:base]` is empty — no single-owner rule exists yet. Test 2 fails because `errors[:password]` is empty for a short password — no length rule exists yet.

Test 3 already passes, and that is fine: with no length rule, `errors[:password]` is trivially empty. It is there as a guard that the rule you add in Step 3 does not over-fire on a valid password.

- [ ] **Step 3: Add the validations**
In `app/models/user.rb`, add a create-time validation rejecting a second row when `User.exists?`, and a minimum password length of 12 with `allow_nil: true` so `has_secure_password`'s "nil means no change" semantics survive updates. Follow the model conventions' ordering: associations → validations → methods.

- [ ] **Step 4: Run and watch them pass**
Run: `bin/rails test test/models/user_test.rb`
Expected: PASS — all three. Test 3 confirms the length rule does not fire on a valid password even though `errors[:base]` carries the single-owner error.

- [ ] **Step 5: Run the full suite**
Run: `bin/rails test`
Expected: all green — confirms the single-owner rule did not break the fixture-backed tests.

- [ ] **Step 6: Commit**
```bash
git add app/models/user.rb test/models/user_test.rb
git commit -m "feat: enforce single owner and minimum password length"
```

---

## Task 6: Seed the owner

**Files:**
- Modify: `db/seeds.rb`, `.env` (untracked), `README.md`

- [ ] **Step 1: Write the seeds**
Replace the commented-out body of `db/seeds.rb`:
```ruby
if ENV["OWNER_EMAIL"].present? && ENV["OWNER_PASSWORD"].present?
  owner = User.first || User.new
  owner.email_address = ENV["OWNER_EMAIL"]
  owner.password      = ENV["OWNER_PASSWORD"]
  owner.save!
  puts "[seeds] owner #{owner.email_address} ready"
else
  Rails.logger.warn "[seeds] OWNER_EMAIL/OWNER_PASSWORD unset — no owner created; sign-in will be impossible until seeded."
  puts "[seeds] skipped owner creation: OWNER_EMAIL/OWNER_PASSWORD unset"
end
```
It **skips rather than raises** by design: `config/ci.rb` runs both `bin/setup --skip-server` and `db:seed:replant`, and `.env` is gitignored, so `ENV.fetch` would turn `bin/ci` red on every fresh clone.

- [ ] **Step 2: Verify the skip path**
Run: `env -u OWNER_EMAIL -u OWNER_PASSWORD bin/rails runner 'load Rails.root.join("db/seeds.rb")'`
Expected: prints the skip message, exits 0, creates nothing.

- [ ] **Step 3: Add the keys to `.env`**
Append `OWNER_EMAIL=` and `OWNER_PASSWORD=` with real local values. **`OWNER_PASSWORD` must be at least 12 characters** (Task 5 adds that validation) or `owner.save!` in the next step raises `ActiveRecord::RecordInvalid`. **Do not commit `.env`** — confirm with `git status --porcelain` that it does not appear.

- [ ] **Step 4: Seed for real**
Run: `bin/rails db:seed`
Expected: `[seeds] owner <your-email> ready`. Re-run it: same output, still exactly one `User` (`bin/rails runner 'puts User.count'` → `1`).

- [ ] **Step 5: Document the keys**
Add `OWNER_EMAIL` and `OWNER_PASSWORD` to the README's environment-variable table, and note that `bin/rails db:seed` creates or updates the owner and that re-seeding rotates the password.

- [ ] **Step 6: Commit**
```bash
git add db/seeds.rb README.md
git commit -m "feat: seed the single owner from environment"
```
Verify `.env` is **not** staged before committing.

---

## Task 7: Sign-in, sign-out, and return-to

**Files:**
- Create: `test/controllers/sessions_controller_test.rb`
- Modify: `app/controllers/sessions_controller.rb`

- [ ] **Step 1: Write the failing tests**
In `test/controllers/sessions_controller_test.rb`, cover:
  - signing in with correct credentials redirects and creates a `Session` row
  - a wrong password **redirects** to `/session/new` with `flash[:alert]` and creates no `Session` — the generated controller redirects; do not assert a re-render or `:unprocessable_entity`
  - sign-out destroys the `Session` row, clears the `session_id` cookie, and sets a notice
  - **return-to replay:** request `/links/new?link[url]=https://example.com/x&link[title]=X` while signed out, sign in, and assert the redirect target retains both params. This is the bookmarklet/extension flow and is the single most valuable test here.

- [ ] **Step 2: Run and watch them fail**
Run: `bin/rails test test/controllers/sessions_controller_test.rb`
Expected: FAIL — the sign-out notice assertion fails; the generated `#destroy` redirects with no message.

- [ ] **Step 3: Add the sign-out notice**
In `SessionsController#destroy`, add `notice: "You have been signed out."` to the redirect. Change nothing else — the rest of the generated controller is the approved behavior.

- [ ] **Step 4: Run and watch them pass**
Run: `bin/rails test`
Expected: all green.

- [ ] **Step 5: Commit**
```bash
git add app/controllers/sessions_controller.rb test/controllers/
git commit -m "feat: sign-out notice, with session and return-to coverage"
```

---

## Task 8: Style the sign-in page and gate the nav

**Files:**
- Modify: `app/views/sessions/new.html.erb`, `app/views/layouts/application.html.erb`

- [ ] **Step 1: Rewrite the sign-in view**
Replace the generated markup with a centered card using the app's existing vocabulary — `glass-strong`, `btn-primary`, `alert`, the `mist` palette, `gradient-cv` on the logo mark. Email and password fields, one submit button. No "remember me", no signup link, no forgot-password link. Use `form_with url: session_path`. The layout already renders `flash[:alert]`, and Task 9 adds `flash[:notice]` there — do **not** re-render flash inside this view or the sign-in page shows the banner twice.

- [ ] **Step 2: Gate the nav**
In the layout, wrap the Bookmarklet / Archive / New link controls in `if authenticated?` and add a sign-out `button_to` to `session_path` with `method: :delete`. Point the logo at `new_session_path` when unauthenticated — otherwise the sign-in page's only visible control bounces back to sign-in.

`authenticated?` is already a `helper_method` on the generated concern; do not add a helper.

- [ ] **Step 3: Verify in the browser**
Start `bin/rails server`, sign out, and load `http://localhost:3000/links`. Confirm: redirect to a styled sign-in page, the nav shows only the logo, signing in returns you to `/links`, and the sign-out button works and shows the notice.

- [ ] **Step 4: Run the tests**
Run: `bin/rails test`
Expected: all green.

- [ ] **Step 5: Commit**
```bash
git add app/views/
git commit -m "style: sign-in page and authenticated nav"
```

---

## Task 9: Consolidate flash rendering

**Files:**
- Modify: `app/views/layouts/application.html.erb`, `app/views/links/index.html.erb`, `app/views/links/show.html.erb`

- [ ] **Step 1: Move `notice` into the layout**
Add a `flash[:notice]` block beside the existing `flash[:alert]` block, using the same `alert alert-success` markup the views currently use.

- [ ] **Step 2: Delete the duplicates**
Remove the `notice` blocks from `links/index.html.erb` (around line 6) and `links/show.html.erb` (around line 16).

- [ ] **Step 3: Verify by hand**
Create a link and confirm the "Saved!" notice still appears — now above `<main>`. Nothing in `test/` references `notice` or `#notice`, so this is not covered by the suite.

- [ ] **Step 4: Run the tests**
Run: `bin/rails test`
Expected: all green.

- [ ] **Step 5: Commit**
```bash
git add app/views/
git commit -m "refactor: render flash notices in the layout"
```

---

## Task 10: Verify Action Cable by hand

The generator added `app/channels/application_cable/connection.rb`, which calls `reject_unauthorized_connection` unless a signed session cookie resolves. `app/channels/` did not exist before, so `/cable` previously accepted **every** connection. **No integration test opens a cable connection, so a broken subscription is invisible to the suite.**

**Files:** none (verification only)

- [ ] **Step 1: Confirm live updates still work**
With the server and `bin/jobs` running and signed in, open `/links` in two tabs, save a link in one, and confirm the other updates without a reload.

- [ ] **Step 2: Check the log**
Expected: no `reject_unauthorized_connection` or "An unauthorized connection attempt was rejected" entries while signed in. If you see them, the cookie is not reaching the cable handshake — investigate before proceeding.

- [ ] **Step 3: Confirm the gate works**
In a private window (signed out), load `/links`. Expected: redirect to sign-in, no cable subscription established.

---

## Task 11: Documentation and final verification

**Files:**
- Modify: `PLAN.md`, `README.md`

- [ ] **Step 1: Check off the plan item**
Tick `Auth` in PLAN.md Phase 6.

- [ ] **Step 2: Record the deploy prerequisites**
Add a short "Before deploying" section to the README listing the three items this feature creates, each with its reason:
  1. Install solid_cache (`bin/rails solid_cache:install`) and set `config.cache_store = :solid_cache_store` — otherwise the sign-in rate limit lives in `tmp/cache` and resets on every release.
  2. Enable `config.force_ssl = true` (or `assume_ssl` behind an upstream terminator) — the session cookie is `httponly` and `same_site: :lax` but not `secure` without it.
  3. Revoke access with `Session.delete_all` from the console. Re-seeding rotates the password but does **not** invalidate existing sessions, and there is deliberately no session-management UI.

Add one line about the accepted rough edge that can actually fail in production: the return-to path stores the full `request.url` in the 4KB cookie session, so a very long tab URL plus title arriving from the extension can raise `CookieOverflow` — a 500 on the save flow. The fix, if it ever bites, is storing `request.fullpath` or skipping the stash past a length threshold.

- [ ] **Step 3: Full verification**
```bash
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```
Expected: tests green, no offenses, no warnings. Brakeman matters here — it flags unprotected redirects and mass-assignment on new auth code.

- [ ] **Step 4: Confirm no secrets are staged**
```bash
git status --porcelain
git diff --cached --stat
```
Expected: `.env` appears nowhere.

- [ ] **Step 5: Commit**
```bash
git add PLAN.md README.md
git commit -m "docs: check off auth and record deploy prerequisites"
```

---

## Done when

- `bin/rails test` is green with sign-in coverage for the gate, the return-to replay, sign-out, and the single-owner rule.
- Signed out, every route except `/session/new`, `POST /session`, and `/up` redirects to sign-in.
- The extension and bookmarklet still land on a prefilled `/links/new` after signing in.
- Live updates still work signed in; `/cable` rejects signed-out connections.
- `bin/ci` passes on a checkout with no `.env`.
- `.env` remains untracked.
