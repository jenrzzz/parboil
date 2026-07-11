require "test_helper"

# Tests the apply half of extraction (schema result -> graph mutations)
# without any LLM: we hand it the structured result the model would return.
class ExtractorApplyTest < ActiveSupport::TestCase
  setup do
    @idea = Idea.create!(seed: "an itch", status: :interviewing)
    @answer = MessageNode.create!(idea: @idea, role: :user, content: "my answer")
  end

  def apply(result)
    Interview::Extractor.new(@idea).send(:apply, result, @answer)
  end

  test "creates typed nodes with provenance and positions" do
    created = apply({ "nodes" => [
      { "node_type" => "claim", "body" => "a point" },
      { "node_type" => "question", "body" => "unresolved?" }
    ] })

    assert_equal 2, created.size
    assert_equal [ 1, 2 ], created.map(&:position)
    assert_equal @answer, created.first.source_message
    assert created.second.open?
  end

  test "thesis flag only sticks to claims" do
    created = apply({ "nodes" => [
      { "node_type" => "claim", "body" => "the spine", "thesis" => true },
      { "node_type" => "hook", "body" => "an opener", "thesis" => true }
    ] })

    assert created.first.thesis?
    assert_not created.second.thesis?
  end

  test "captures audience once and never overwrites" do
    apply({ "nodes" => [], "audience" => "junior engineers" })
    assert_equal "junior engineers", @idea.reload.audience

    apply({ "nodes" => [], "audience" => "someone else" })
    assert_equal "junior engineers", @idea.reload.audience
  end

  test "skips unknown types and blank bodies, tolerates empty result" do
    created = apply({ "nodes" => [
      { "node_type" => "sonnet", "body" => "nope" },
      { "node_type" => "claim", "body" => "  " }
    ] })
    assert_empty created
    assert_empty apply({})
  end

  test "ripens the idea when the extraction completes the checklist" do
    @idea.update!(audience: "writers")
    @idea.idea_nodes.create!(node_type: :counterpoint, body: "but", position: 90)
    @idea.idea_nodes.create!(node_type: :hook, body: "hook", position: 91)
    2.times { |i| @idea.idea_nodes.create!(node_type: :example, body: "ex#{i}", position: 92 + i) }

    apply({ "nodes" => [
      { "node_type" => "claim", "body" => "the spine", "thesis" => true },
      { "node_type" => "example", "body" => "third example" }
    ] })

    assert @idea.reload.ripe?
  end
end
