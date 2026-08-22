require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "signed out request to links index redirects to sign in" do
    get links_url

    assert_redirected_to "/session/new"
  end
end
