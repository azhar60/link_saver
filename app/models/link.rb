class Link < ApplicationRecord
  enum :status, { pending: "pending", processing: "processing", ready: "ready", failed: "failed" }

  validates :url, presence: true, format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" }
end
