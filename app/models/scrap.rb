# A piece of raw material dropped into an idea: a pasted excerpt or a link.
# Scraps are interviewer context and outline references — they are NOT the
# writer's words, so the extractor never turns them into graph nodes.
class Scrap < ApplicationRecord
  belongs_to :idea, touch: true

  enum :kind, { paste: 0, link: 1 }

  validates :body, presence: true, if: :paste?
  validates :url, presence: true, format: { with: %r{\Ahttps?://}i, message: "must be http(s)" }, if: :link?

  scope :ordered, -> { order(:created_at) }

  # Fetch failed or hasn't produced text — the link itself is still useful.
  def unfetched?
    link? && body.blank?
  end

  def display_title
    title.presence || (link? ? host : body.to_s.truncate(60))
  end

  def host
    URI.parse(url).host&.delete_prefix("www.")
  rescue URI::InvalidURIError
    url
  end
end
