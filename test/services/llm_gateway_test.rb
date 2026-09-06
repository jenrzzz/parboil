require "test_helper"

# The handoff to hob: what parboil sends, what comes back, and how hob's
# errors surface as the one LLM::Error the controllers rescue.
class LLMGatewayTest < ActiveSupport::TestCase
  setup do
    @fake = Hob::Fake.new
    LLM.client = @fake
  end

  teardown { LLM.client = nil }

  test "a text completion sends role, system, ledger fields and the realm" do
    @fake.reply("What broke first?")
    text = LLM::Gateway.complete(
      role: :interviewer, system: "Ask one question.", messages: "seed: an itch",
      operation: "interview.open", metadata: { idea_id: 7 }, ref: "idea/7"
    )

    assert_equal "What broke first?", text
    call = @fake.calls.sole.args
    assert_equal "interviewer", call[:role]
    assert_equal "Ask one question.", call[:system]
    assert_equal [ { role: "user", content: "seed: an itch" } ], call[:messages]
    assert_equal "interview.open", call[:operation]
    assert_equal "idea/7", call[:ref]
    assert_equal "personal", call[:realm]
    assert_nil call[:model]
  end

  test "a schema completion returns the parsed object and defaults operation to the role" do
    @fake.reply({ nodes: [ { node_type: "claim", body: "a point" } ] }.to_json)
    result = LLM::Gateway.complete(role: :extractor, messages: "answer", schema: Interview::Extractor::SCHEMA)

    assert_equal "a point", result.dig("nodes", 0, "body")
    assert_equal "extractor", @fake.calls.sole.args[:operation]
    assert_equal Interview::Extractor::SCHEMA, @fake.calls.sole.args[:schema]
  end

  test "hob's errors become LLM::Error" do
    @fake.refuse
    e = assert_raises(LLM::Error) { LLM::Gateway.complete(role: :interviewer, messages: "x") }
    assert_match(/declined/, e.message)

    @fake.fail(Hob::RateLimited.new("slow down", retry_after: 3))
    assert_match(/rate limited/, assert_raises(LLM::Error) { LLM::Gateway.complete(role: :interviewer, messages: "x") }.message)

    @fake.fail(Hob::Unavailable.new("down"))
    assert_match(/hob error: down/, assert_raises(LLM::Error) { LLM::Gateway.complete(role: :interviewer, messages: "x") }.message)
  end

  test "without hob configured the gateway raises before any call" do
    LLM.client = nil
    ENV.delete("HOB_URL")
    assert_not LLM.enabled?
    assert_raises(LLM::NotConfigured) { LLM::Gateway.complete(role: :interviewer, messages: "x") }
  end
end
