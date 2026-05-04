require "test_helper"

class PageFetcherTest < ActiveSupport::TestCase
  test "valid URL returns title and content" do
    body = <<~HTML
      <html>
        <head><title>  Hello World  </title></head>
        <body>
          <nav>nav menu</nav>
          <script>var x = 1;</script>
          <style>.foo { color: red }</style>
          <main>The quick brown fox jumps over the lazy dog.</main>
          <footer>footer text</footer>
        </body>
      </html>
    HTML
    stub_request(:get, "https://example.com/article").to_return(status: 200, body: body)

    result = PageFetcher.fetch("https://example.com/article")

    assert_equal "Hello World", result[:title]
    assert_includes result[:content], "The quick brown fox"
    refute_includes result[:content], "var x = 1"
    refute_includes result[:content], "color: red"
    refute_includes result[:content], "nav menu"
    refute_includes result[:content], "footer text"
  end

  test "truncates content to 6000 chars" do
    long_text = "a" * 10_000
    stub_request(:get, "https://example.com/long").to_return(status: 200, body: "<html><body>#{long_text}</body></html>")

    result = PageFetcher.fetch("https://example.com/long")

    assert_equal 6_000, result[:content].length
  end

  test "non-2xx response returns nil" do
    stub_request(:get, "https://example.com/missing").to_return(status: 404, body: "not found")

    assert_nil PageFetcher.fetch("https://example.com/missing")
  end

  test "network error returns nil" do
    stub_request(:get, "https://example.com/timeout").to_timeout

    assert_nil PageFetcher.fetch("https://example.com/timeout")
  end

  test "DNS failure returns nil" do
    stub_request(:get, "https://nope.invalid/").to_raise(SocketError.new("getaddrinfo: nodename nor servname provided"))

    assert_nil PageFetcher.fetch("https://nope.invalid/")
  end
end
