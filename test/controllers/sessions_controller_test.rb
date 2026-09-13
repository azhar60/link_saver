require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
  end

  test "shows the sign in page when signed out" do
    get new_session_url

    assert_response :success
  end

  test "signing in creates a session and redirects" do
    assert_difference("Session.count", 1) do
      sign_in_as @owner
    end

    assert_redirected_to root_url
  end

  test "a wrong password redirects back with an alert and no session" do
    assert_no_difference("Session.count") do
      sign_in_as @owner, password: "wrongpassword"
    end

    assert_redirected_to new_session_path
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "signing out destroys the session, clears the cookie, and says so" do
    sign_in_as @owner

    assert_difference("Session.count", -1) do
      delete session_url
    end

    assert_redirected_to new_session_path
    assert_equal "You have been signed out.", flash[:notice]
    assert_predicate cookies[:session_id].to_s, :empty?
  end

  test "replays the originally requested url after signing in" do
    get new_link_url(link: { url: "https://example.com/x", title: "Example X" })
    assert_redirected_to "/session/new"

    sign_in_as @owner

    location = CGI.unescape(response.location)
    assert_includes location, "/links/new"
    assert_includes location, "link[url]=https://example.com/x"
    assert_includes location, "link[title]=Example X"
  end
end
