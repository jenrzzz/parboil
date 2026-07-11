require "test_helper"

class IdeasControllerTest < ActionDispatch::IntegrationTest
  test "index renders with seed capture" do
    get root_path
    assert_response :success
    assert_select "textarea[name=?]", "idea[seed]"
  end

  test "creates an idea without any LLM call" do
    assert_difference -> { Idea.count } do
      assert_no_difference -> { LLMUsage.count } do
        post ideas_path, params: { idea: { seed: "an itch" } }
      end
    end
    assert_redirected_to idea_path(Idea.last)
    assert Idea.last.seeded?
  end

  test "show renders seeded idea with start button and scraps drop-in" do
    idea = Idea.create!(seed: "an itch")
    get idea_path(idea)
    assert_response :success
    assert_select "form[action=?]", next_question_idea_path(idea)
    assert_select "form[action=?]", idea_scraps_path(idea)
  end

  test "show renders graph svg and ripeness checklist for an interviewing idea" do
    idea = Idea.create!(seed: "an itch", status: :interviewing, head_hash: "x" * 64)
    node = MessageNode.create!(idea: idea, role: :interviewer, content: "q?")
    idea.update!(head_hash: node.content_hash)
    claim = idea.idea_nodes.create!(node_type: :claim, body: "spine", thesis: true, position: 1)
    idea.idea_nodes.create!(node_type: :example, body: "kid", position: 2, parent: claim)

    get idea_path(idea)
    assert_response :success
    assert_select "svg.idea-graph"
    assert_select "svg.idea-graph g.graph-node", 3 # center + 2 nodes
    assert_select ".checklist li", 5
    assert_select ".checklist li.met", 1 # thesis only
  end

  test "outline puts thesis claim first and audience in frontmatter" do
    idea = Idea.create!(seed: "an itch", audience: "tired reviewers")
    idea.idea_nodes.create!(node_type: :claim, body: "later point", position: 1)
    idea.idea_nodes.create!(node_type: :claim, body: "the spine", thesis: true, position: 2)

    get outline_idea_path(idea, format: :md)
    assert_includes response.body, %(audience: "tired reviewers")
    assert_includes response.body, %(thesis: "the spine")
    assert_operator response.body.index("## the spine"), :<, response.body.index("## later point")
  end

  test "outline renders markdown with scrap links in references" do
    idea = Idea.create!(seed: "an itch")
    idea.idea_nodes.create!(node_type: :claim, body: "a claim", position: 1)
    idea.scraps.create!(kind: :link, url: "https://example.com/x", title: "Ex")
    get outline_idea_path(idea, format: :md)
    assert_response :success
    assert_match "text/markdown", response.content_type
    assert_includes response.body, "## a claim"
    assert_includes response.body, "- [Ex](https://example.com/x)"
  end
end
