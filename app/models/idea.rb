# One blog idea: a seed, the interview that grows it, and the typed graph
# extracted from that interview. The unit of everything in parboil.
class Idea < ApplicationRecord
  # Message nodes are immutable (readonly? once persisted), so they can't be
  # instantiated-and-destroyed; delete_all is the right teardown and matches the
  # semantics — individual turns are never destroyed, but wiping the idea is.
  has_many :message_nodes, dependent: :delete_all
  has_many :idea_nodes, dependent: :destroy
  has_many :scraps, dependent: :destroy

  # seeded      — captured, not yet interviewed
  # interviewing — an interview is underway
  # ripe        — coverage met; draft-ready (the finish line; v2 lights the meter)
  enum :status, { seeded: 0, interviewing: 1, ripe: 2 }

  validates :seed, presence: true

  # The current leaf of the interview DAG. hob keeps a `branches` table; v1 has
  # a single branch, so one pointer on the idea is the whole of it.
  def head
    head_hash && message_nodes.find_by(content_hash: head_hash)
  end

  # The interview transcript, root-first. Empty until the first turn.
  def transcript
    head&.thread_chain || []
  end

  def display_title
    title.presence || seed.to_s.truncate(60)
  end
end
