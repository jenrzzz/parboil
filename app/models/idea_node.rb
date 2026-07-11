# A typed node in the idea graph — a single point the interview surfaced,
# extracted verbatim from the user's own words. These, ordered, become the
# outline. The LLM never writes the body; it only classifies and extracts.
class IdeaNode < ApplicationRecord
  belongs_to :idea
  belongs_to :parent, class_name: "IdeaNode", optional: true
  has_many :children, class_name: "IdeaNode", foreign_key: :parent_id, dependent: :nullify
  # Provenance: the interview answer this was extracted from (hob's rule — the
  # graph must know *why* it believes things). Nullable; survives node deletion.
  belongs_to :source_message, class_name: "MessageNode",
             foreign_key: :source_message_hash, primary_key: :content_hash, optional: true

  # The vocabulary the interview extracts into (DESIGN.md).
  enum :node_type, {
    claim:        0,   # a thing the post asserts
    example:      1,   # concrete instance backing a claim
    question:     2,   # open thread the idea still needs to answer
    counterpoint: 3,   # objection / the strongest disagreement
    reference:    4,   # external source, link, prior art
    hook:         5    # candidate opening
  }

  # Meaningful mainly for `question` nodes; everything else stays settled.
  enum :status, { settled: 0, open: 1 }

  validates :body, presence: true

  scope :ordered,        -> { order(:position, :created_at) }
  scope :roots,          -> { where(parent_id: nil) }
  scope :open_questions, -> { question.open }
end
