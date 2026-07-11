module Graph
  # Radial-tree geometry for the read-only graph render (DESIGN v2): the idea
  # at the center, root nodes ringed around it grouped by type, children
  # fanning outward near their parent's angle. Pure Ruby, no layout library —
  # the graph is a shallow tree and a mind-map ring is all v2 asks for.
  # Interaction (click-to-focus) lives in the Stimulus controller; this class
  # only computes positions.
  class Layout
    RING_BASE = 170
    RING_STEP = 140
    LABEL_MARGIN = 90
    FAN = 0.42 # radians between siblings in a child fan

    # Claims (the spine) get visual weight; supporting types cluster after.
    TYPE_ORDER = %w[hook claim counterpoint example question reference].freeze
    RADII = { "claim" => 24, "hook" => 20 }.freeze

    Node = Data.define(:id, :type, :body, :label, :x, :y, :r, :thesis, :open, :neighbors)
    Edge = Data.define(:from, :to, :x1, :y1, :x2, :y2)

    attr_reader :idea, :nodes, :edges

    def initialize(idea)
      @idea = idea
      @all = idea.idea_nodes.ordered.to_a
      @nodes = []
      @edges = []
      @max_depth = 1
      compute
    end

    def empty? = @all.empty?

    def center_label = idea.display_title.truncate(30)

    def center_neighbors
      roots.map(&:id).join(",")
    end

    # Half-extent of the square viewBox.
    def extent
      RING_BASE + RING_STEP * (@max_depth - 1) + LABEL_MARGIN
    end

    private

    def roots
      @roots ||= @all.select { |n| n.parent_id.nil? }
                     .sort_by { |n| [ TYPE_ORDER.index(n.node_type) || TYPE_ORDER.size, n.position ] }
    end

    def children_of(node)
      @all.select { |n| n.parent_id == node.id }
    end

    def compute
      return if roots.empty?

      step = 2 * Math::PI / roots.size
      roots.each_with_index do |root, i|
        place(root, -Math::PI / 2 + i * step, 1, parent_id: nil, parent_pos: [ 0, 0 ])
      end
    end

    def place(record, angle, depth, parent_id:, parent_pos:)
      @max_depth = [ @max_depth, depth ].max
      radius = RING_BASE + RING_STEP * (depth - 1)
      x = (radius * Math.cos(angle)).round(1)
      y = (radius * Math.sin(angle)).round(1)

      kids = children_of(record)
      neighbor_ids = [ parent_id, *kids.map(&:id) ].compact
      # Roots also neighbor the center (id 0) so focusing one keeps it lit.
      neighbor_ids << 0 if parent_id.nil?

      @nodes << Node.new(
        id: record.id, type: record.node_type, body: record.body,
        label: record.body.truncate(26), x: x, y: y,
        r: record.thesis? ? 30 : (RADII[record.node_type] || 17),
        thesis: record.thesis?, open: record.open? && record.question?,
        neighbors: neighbor_ids.join(",")
      )
      @edges << Edge.new(from: parent_id || 0, to: record.id,
                         x1: parent_pos[0], y1: parent_pos[1], x2: x, y2: y)

      # Fan the children around the parent's bearing, tighter on deeper rings.
      kids.each_with_index do |kid, j|
        offset = (j - (kids.size - 1) / 2.0) * (FAN / depth)
        place(kid, angle + offset, depth + 1, parent_id: record.id, parent_pos: [ x, y ])
      end
    end
  end
end
