class Link < ApplicationRecord
  enum :status, { pending: "pending", processing: "processing", ready: "ready", failed: "failed" }

  validates :url, presence: true, format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" }

  scope :tagged_with, ->(tag) { where("tags ILIKE ?", "%#{sanitize_sql_like(tag.to_s)}%") }
  scope :search, ->(query) {
    term = "%#{sanitize_sql_like(query.to_s)}%"
    where("title ILIKE :t OR summary ILIKE :t", t: term)
  }

  def tag_list
    tags.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  # Fetches the page, fills in title (if blank), and asks Gemini to summarize.
  # Sets status to :ready on success, :failed if the page or AI step fails.
  # Returns true if the page was fetched, false if the fetch failed
  # (caller can flash a warning about the fallback title).
  # Always returns gracefully — never raises.
  def process_via_ai
    fetched = PageFetcher.fetch(url)
    self.title = fetched&.dig(:title).presence || fallback_title if title.blank?
    apply_ai_summary(fetched&.dig(:content))
    fetched.present?
  rescue => e
    Rails.logger.warn("[Link#process_via_ai] #{id || url}: #{e.class} #{e.message}")
    self.title = fallback_title if title.blank?
    self.status = :failed
    false
  end

  private

  def apply_ai_summary(content)
    if content.present? && (result = GeminiClient.summarize(content))
      self.summary = result[:summary]
      self.tags = Array(result[:tags]).join(",")
      self.status = :ready
    else
      self.status = :failed
    end
  end

  def fallback_title
    URI.parse(url).host || url
  rescue URI::InvalidURIError
    url
  end
end
