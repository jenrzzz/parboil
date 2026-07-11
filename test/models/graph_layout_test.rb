require "test_helper"

class GraphLayoutTest < ActiveSupport::TestCase
  setup do
    @idea = Idea.create!(seed: "graph geometry")
  end

  test "empty graph" do
    assert Graph::Layout.new(@idea).empty?
  end

  test "every node gets a position and exactly one inbound edge" do
    claim = @idea.idea_nodes.create!(node_type: :claim, body: "root claim", position: 1)
    @idea.idea_nodes.create!(node_type: :example, body: "child", position: 2, parent: claim)
    @idea.idea_nodes.create!(node_type: :hook, body: "another root", position: 3)

    layout = Graph::Layout.new(@idea)
    assert_equal 3, layout.nodes.size
    assert_equal 3, layout.edges.size

    inbound = layout.edges.group_by(&:to)
    layout.nodes.each { |n| assert_equal 1, inbound[n.id].size }
  end

  test "children sit on a deeper ring than their parents" do
    claim = @idea.idea_nodes.create!(node_type: :claim, body: "root", position: 1)
    @idea.idea_nodes.create!(node_type: :example, body: "child", position: 2, parent: claim)

    layout = Graph::Layout.new(@idea)
    by_id = layout.nodes.index_by(&:id)
    root_dist  = Math.hypot(by_id[claim.id].x, by_id[claim.id].y)
    child = layout.nodes.find { |n| n.type == "example" }
    child_dist = Math.hypot(child.x, child.y)

    assert child_dist > root_dist
    assert_operator layout.extent, :>, child_dist
  end

  test "roots neighbor the center and their children" do
    claim = @idea.idea_nodes.create!(node_type: :claim, body: "root", position: 1)
    kid = @idea.idea_nodes.create!(node_type: :example, body: "child", position: 2, parent: claim)

    layout = Graph::Layout.new(@idea)
    root_node = layout.nodes.find { |n| n.id == claim.id }
    assert_includes root_node.neighbors.split(","), "0"
    assert_includes root_node.neighbors.split(","), kid.id.to_s
    assert_includes layout.center_neighbors.split(","), claim.id.to_s
  end

  test "thesis nodes render larger" do
    @idea.idea_nodes.create!(node_type: :claim, body: "spine", thesis: true, position: 1)
    @idea.idea_nodes.create!(node_type: :claim, body: "side", position: 2)

    radii = Graph::Layout.new(@idea).nodes.map { |n| [ n.thesis, n.r ] }.to_h
    assert_operator radii[true], :>, radii[false]
  end
end
