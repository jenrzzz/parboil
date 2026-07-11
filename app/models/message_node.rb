# frozen_string_literal: true

# One turn of the interview, as a content-addressed immutable node (git for
# chat, lifted from kat). content_hash = H(role, speaker, content, parent_hash),
# parent-chained — so regenerating a question is a new sibling node, nothing is
# ever destroyed, and re-importing is a no-op. This is hob's conversation DAG.
class MessageNode < ApplicationRecord
  self.primary_key = "content_hash"

  belongs_to :idea
  belongs_to :parent, class_name: "MessageNode",
             foreign_key: :parent_hash, primary_key: :content_hash, optional: true
  has_many :children, class_name: "MessageNode",
           foreign_key: :parent_hash, primary_key: :content_hash
  # Typed nodes extracted from this turn's answer (provenance).
  has_many :extracted_nodes, class_name: "IdeaNode",
           foreign_key: :source_message_hash, primary_key: :content_hash, dependent: :nullify

  enum :role, { user: 0, interviewer: 1, system: 2 }

  validates :content, presence: true
  validates :content_hash, presence: true, uniqueness: true

  before_validation :compute_content_hash, on: :create

  # Immutable after creation.
  def readonly?
    persisted?
  end

  # Deterministic content address: same inputs → same hash.
  def self.compute_hash(role:, speaker_name:, content:, parent_hash:)
    payload = [ role.to_s, speaker_name.to_s, content.to_s, parent_hash.to_s ].join("\0")
    Digest::SHA256.hexdigest(payload)
  end

  # Walk the parent chain to the root; ordered array, root first.
  def thread_chain
    chain = [ self ]
    current = self
    while current.parent_hash.present?
      current = self.class.find_by(content_hash: current.parent_hash)
      break unless current
      chain.unshift(current)
    end
    chain
  end

  def root?
    parent_hash.nil?
  end

  def leaf?
    children.empty?
  end

  private

  def compute_content_hash
    self.content_hash ||= self.class.compute_hash(
      role: role, speaker_name: speaker_name, content: content, parent_hash: parent_hash
    )
  end
end
