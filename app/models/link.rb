class Link < ApplicationRecord
  enum :status, { pending: "pending", processing: "processing", ready: "ready", failed: "failed" }

  validates :url, presence: true, format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" }

  # Fetches the URL and fills in title from the page. Respects a user-supplied title.
  # Returns true on a successful fetch, false if fetch failed (caller can flash a warning).
  def populate_metadata
    return true if title.present?

    result = PageFetcher.fetch(url)
    if result && result[:title].present?
      self.title = result[:title]
      true
    else
      self.title = fallback_title
      false
    end
  end

  private

  def fallback_title
    URI.parse(url).host || url
  rescue URI::InvalidURIError
    url
  end
end
