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
