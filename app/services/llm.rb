require "hob"

# parboil's LLM seam, now a real handoff to hob — the household LLM
# substrate. Surfaces never ask for a model ID: they ask for a *role*
# (`interviewer`, `extractor`) and hob resolves it to a model chain. The
# usage ledger lives in hob too (`GET /v1/usage`, grouped by operation and
# ref), so parboil keeps no table of its own.
module LLM
  class Error < StandardError; end
  class NotConfigured < Error; end

  # Blog work is public-identity, not household or intimate: `personal`
  # clearance (DESIGN.md, fleet grounding), so the surface key needs at
  # least that.
  REALM = "personal".freeze

  module_function

  def url = ENV["HOB_URL"].presence
  def key = ENV["HOB_KEY"].presence

  def enabled?
    url.present? && key.present?
  end

  # Tests inject Hob::Fake; production builds a real client lazily so booting
  # without hob configured is fine — LLM turns then error politely.
  def client
    @client ||= begin
      raise NotConfigured, "HOB_URL and HOB_KEY are not set" unless enabled?
      Hob::Client.new(base: url, key: key)
    end
  end

  def client=(fake)
    @client = fake
  end
end
