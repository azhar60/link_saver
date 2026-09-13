# Creates or updates the single owner account from the environment.
#
# Set OWNER_EMAIL and OWNER_PASSWORD in .env (never commit it), then run:
#   bin/rails db:seed
#
# Idempotent: re-seeding rotates the password, and changing OWNER_EMAIL renames the
# existing owner rather than creating a second one — User enforces a single owner.
#
# Skips rather than raises when the vars are unset, because bin/setup and config/ci.rb
# both run seeds and .env is gitignored, so a fresh clone or CI runner has neither var.
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
