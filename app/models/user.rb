class User < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 12

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true
  validate :only_one_owner, on: :create

  private
    # This app has exactly one owner, seeded from the environment. Enforcing it here
    # means the invariant survives a stray User.create in the console, not just the
    # absence of a signup route.
    def only_one_owner
      errors.add(:base, "only one owner account is allowed") if User.exists?
    end
end
