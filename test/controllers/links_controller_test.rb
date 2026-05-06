require "test_helper"

class LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @link = links(:one)
  end

  test "should get index" do
    get links_url
    assert_response :success
  end

  test "should get new" do
    get new_link_url
    assert_response :success
  end

  test "should create link" do
    stub_request(:get, "https://example.com/one")
      .to_return(status: 200, body: "<html><head><title>Stubbed</title></head><body>hello</body></html>")
    stub_request(:post, %r{generativelanguage\.googleapis\.com})
      .to_return(status: 200, body: { candidates: [ { content: { parts: [ { text: '{"summary":"s","tags":["a"]}' } ] } } ] }.to_json)

    assert_difference("Link.count") do
      post links_url, params: { link: { status: @link.status, summary: @link.summary, tags: @link.tags, title: @link.title, url: @link.url } }
    end

    assert_redirected_to link_url(Link.last)
  end

  test "should show link" do
    get link_url(@link)
    assert_response :success
  end

  test "should get edit" do
    get edit_link_url(@link)
    assert_response :success
  end

  test "should update link" do
    patch link_url(@link), params: { link: { status: @link.status, summary: @link.summary, tags: @link.tags, title: @link.title, url: @link.url } }
    assert_redirected_to link_url(@link)
  end

  test "should destroy link" do
    assert_difference("Link.count", -1) do
      delete link_url(@link)
    end

    assert_redirected_to links_url
  end
end
