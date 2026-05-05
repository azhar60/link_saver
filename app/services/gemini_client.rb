require "httparty"
require "json"

class GeminiClient
  ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent".freeze
  TIMEOUT = 30

  PROMPT = <<~PROMPT.freeze
    Summarize the text below in 2 to 3 sentences, then list 3 to 5 short topic tags.
    Return ONLY a JSON object with this exact shape:
    {"summary": "...", "tags": ["tag1", "tag2", "tag3"]}

    Text:
  PROMPT

  def self.summarize(text)
    new(text).summarize
  end

  def initialize(text)
    @text = text.to_s
  end

  def summarize
    return nil if @text.strip.empty?
    return nil if api_key.blank?

    response = HTTParty.post(
      ENDPOINT,
      timeout: TIMEOUT,
      headers: {
        "Content-Type" => "application/json",
        "x-goog-api-key" => api_key
      },
      body: request_body.to_json
    )
    return nil unless response.success?

    raw_text = response.dig("candidates", 0, "content", "parts", 0, "text")
    return nil if raw_text.blank?

    parse_payload(raw_text)
  rescue HTTParty::Error, Net::ReadTimeout, Net::OpenTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, OpenSSL::SSL::SSLError, Timeout::Error, JSON::ParserError => e
    Rails.logger.warn("[GeminiClient] #{e.class} #{e.message}")
    nil
  end

  private

  def api_key
    ENV["GEMINI_API_KEY"]
  end

  def request_body
    {
      contents: [{ parts: [{ text: "#{PROMPT}#{@text}" }] }],
      generationConfig: { responseMimeType: "application/json" }
    }
  end

  def parse_payload(raw_text)
    cleaned = raw_text.strip.sub(/\A```(?:json)?\s*/i, "").sub(/```\s*\z/, "").strip
    parsed = JSON.parse(cleaned)
    {
      summary: parsed["summary"].to_s.strip,
      tags: Array(parsed["tags"]).map { |t| t.to_s.strip }.reject(&:empty?)
    }
  end
end
