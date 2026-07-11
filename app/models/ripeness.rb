# The finish line (DESIGN.md): a coverage checklist that makes "fleshed out
# enough to draft" a concrete, visible state instead of a feeling. All five
# checks are deterministic reads of the graph — no LLM opinion involved, so
# the writer can always see exactly what's missing and why.
class Ripeness
  Check = Data.define(:key, :label, :met, :detail)

  EXAMPLES_NEEDED = 3

  def initialize(idea)
    @idea = idea
    # Ruby-side over the loaded association so index pages can preload
    # idea_nodes instead of running five COUNTs per idea.
    @nodes = idea.idea_nodes.to_a
  end

  def checks
    @checks ||= [
      thesis_check,
      audience_check,
      examples_check,
      counterpoint_check,
      hook_check
    ]
  end

  def ripe? = checks.all?(&:met)
  def met_count = checks.count(&:met)
  def total = checks.size
  def missing = checks.reject(&:met)

  private

  attr_reader :idea, :nodes

  def count_of(type) = nodes.count { |n| n.node_type == type.to_s }

  def thesis_check
    met = nodes.any? { |n| n.thesis? }
    Check.new(key: :thesis, label: "thesis stated", met: met,
              detail: met ? nil : "the one claim the post hangs on")
  end

  def audience_check
    met = idea.audience.present?
    Check.new(key: :audience, label: "audience named", met: met,
              detail: met ? idea.audience : "who is this for?")
  end

  def examples_check
    count = count_of(:example)
    Check.new(key: :examples, label: "#{EXAMPLES_NEEDED} concrete examples", met: count >= EXAMPLES_NEEDED,
              detail: "#{count} of #{EXAMPLES_NEEDED}")
  end

  def counterpoint_check
    met = count_of(:counterpoint).positive?
    Check.new(key: :counterpoint, label: "counterargument addressed", met: met,
              detail: met ? nil : "what would the smartest disagreement say?")
  end

  def hook_check
    met = count_of(:hook).positive?
    Check.new(key: :hook, label: "opening hook exists", met: met,
              detail: met ? nil : "a way in for the reader")
  end
end
