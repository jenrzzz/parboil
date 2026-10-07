# A piece of raw material dropped into an idea: a pasted excerpt or a link.
# Scraps are interviewer context and outline references — they are NOT the
# writer's words, so the extractor never turns them into graph nodes.
class Scrap < ApplicationRecord
  belongs_to :idea, touch: true

  enum :kind, { paste: 0, link: 1 }

  validates :body, presence: true, if: :paste?
  validates :url, presence: true, if: :link?
  validate :url_must_be_http, if: :link?

  scope :ordered, -> { order(:created_at) }

  # Fetch failed or hasn't produced text — the link itself is still useful.
  def unfetched?
    link? && body.blank?
  end

  def display_title
    title.presence || (link? ? host : body.to_s.truncate(60))
  end

  def http_url
    parsed_http_url&.to_s
  end

  def host
    parsed_http_url&.host&.delete_prefix("www.") || url
  end

  private

  def parsed_http_url
    uri = URI.parse(url.to_s)
    uri if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  def url_must_be_http
    errors.add(:url, "must be http(s)") unless http_url
  end
end
