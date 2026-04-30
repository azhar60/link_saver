require "httparty"
require "nokogiri"

class PageFetcher
  CONTENT_LIMIT = 6_000
  TIMEOUT = 10
  STRIPPED_SELECTORS = %w[script style nav footer noscript iframe svg].freeze

  def self.fetch(url)
    new(url).fetch
  end

  def initialize(url)
    @url = url
  end

  def fetch
    response = HTTParty.get(
      @url,
      timeout: TIMEOUT,
      follow_redirects: true,
      headers: { "User-Agent" => "LinkSaver/1.0 (+https://github.com/azhar60/link_saver)" }
    )
    return nil unless response.success?

    doc = Nokogiri::HTML(response.body)
    doc.css(STRIPPED_SELECTORS.join(",")).each(&:remove)

    {
      title: doc.at_css("title")&.text&.strip,
      content: doc.text.gsub(/\s+/, " ").strip.first(CONTENT_LIMIT)
    }
  rescue HTTParty::Error, Net::ReadTimeout, Net::OpenTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError, Timeout::Error => e
    Rails.logger.warn("[PageFetcher] #{@url}: #{e.class} #{e.message}")
    nil
  end
end
