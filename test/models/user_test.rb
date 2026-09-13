require "test_helper"

class UserTest < ActiveSupport::TestCase
  # The fixture already supplies the one owner, so `only_one_owner` fires for every
  # user built here. That makes `valid?` useless for the password tests below —
  # they assert on errors[:password] specifically.
  test "rejects a second owner" do
    second = User.new(email_address: "second@example.com", password: "longenough12")

    second.valid?

    assert_includes second.errors[:base], "only one owner account is allowed"
  end

  test "rejects a password under 12 characters" do
    user = User.new(email_address: "short@example.com", password: "short")

    user.valid?

    assert_not_empty user.errors[:password]
  end

  test "accepts a password of 12 characters or more" do
    user = User.new(email_address: "long@example.com", password: "longenough12")

    user.valid?

    assert_empty user.errors[:password]
  end
end
