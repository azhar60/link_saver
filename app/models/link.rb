class Link < ApplicationRecord
  broadcasts_refreshes
  after_commit -> { broadcast_refresh_later_to("links") }, on: %i[create update destroy]

  enum :status, { pending: "pending", processing: "processing", ready: "ready", failed: "failed" }

  validates :url, presence: true, format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" }

  scope :tagged_with, ->(tag) { where("tags ILIKE ?", "%#{sanitize_sql_like(tag.to_s)}%") }
  scope :search, ->(query) {
    term = "%#{sanitize_sql_like(query.to_s)}%"
    where("title ILIKE :t OR summary ILIKE :t", t: term)
  }
  scope :active,   -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archived? = archived_at.present?
  def archive!   = update!(archived_at: Time.current)
  def unarchive! = update!(archived_at: nil)

  WORDS_PER_MINUTE = 200

  def reading_time_minutes
    return nil unless word_count&.positive?
    [(word_count.to_f / WORDS_PER_MINUTE).ceil, 1].max
  end

  # Other non-archived links that share at least one tag.
  # Ranks by number of overlapping tags, then most recent.
  def related(limit: 5)
    return [] if tag_list.empty?

    likes      = tag_list.map { |t| "%#{Link.sanitize_sql_like(t)}%" }
    where_expr = tag_list.map { "tags ILIKE ?" }.join(" OR ")

    candidates = Link.active
                     .where.not(id: id)
                     .where(where_expr, *likes)
                     .order(created_at: :desc)
                     .limit(limit * 3)
                     .to_a

    my_tags = tag_list.map(&:downcase).to_set
    candidates
      .sort_by { |c| [ -(c.tag_list.map(&:downcase).to_set & my_tags).size, -c.created_at.to_i ] }
      .first(limit)
  end

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
    content = fetched&.dig(:content)
    self.word_count = content.to_s.split.length if content.present?
    apply_ai_summary(content)
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
