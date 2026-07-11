require "test_helper"

class RipenessTest < ActiveSupport::TestCase
  setup do
    @idea = Idea.create!(seed: "an itch", status: :interviewing)
  end

  test "fresh idea fails all five checks" do
    r = @idea.ripeness
    assert_equal 5, r.total
    assert_equal 0, r.met_count
    assert_not r.ripe?
  end

  test "a non-thesis claim does not satisfy the thesis check" do
    @idea.idea_nodes.create!(node_type: :claim, body: "a side point", position: 1)
    assert_not @idea.ripeness.checks.find { |c| c.key == :thesis }.met
  end

  test "ripe when all five criteria are met and ripen_if_ready! transitions" do
    fill_checklist(@idea)
    assert @idea.ripeness.ripe?

    @idea.ripen_if_ready!
    assert @idea.reload.ripe?
  end

  test "ripen_if_ready! does nothing while checks are unmet" do
    @idea.idea_nodes.create!(node_type: :hook, body: "hook", position: 1)
    @idea.ripen_if_ready!
    assert @idea.reload.interviewing?
  end

  test "examples check counts and reports progress" do
    @idea.idea_nodes.create!(node_type: :example, body: "one", position: 1)
    check = @idea.ripeness.checks.find { |c| c.key == :examples }
    assert_not check.met
    assert_equal "1 of 3", check.detail
  end

  private

  def fill_checklist(idea)
    idea.idea_nodes.create!(node_type: :claim, body: "the spine", thesis: true, position: 1)
    idea.update!(audience: "engineers who write")
    3.times { |i| idea.idea_nodes.create!(node_type: :example, body: "ex #{i}", position: 2 + i) }
    idea.idea_nodes.create!(node_type: :counterpoint, body: "but", position: 5)
    idea.idea_nodes.create!(node_type: :hook, body: "hook", position: 6)
  end
end
