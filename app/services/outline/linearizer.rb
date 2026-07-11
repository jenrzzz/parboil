module Outline
  # Orders the typed idea graph into a markdown outline — headings plus the
  # writer's own bullets, nothing else. Deterministic and LLM-free: linearize
  # must be instant, repeatable, and incapable of writing prose. This is the
  # handoff artifact; drafting happens in the writer's editor.
  #
  # Shape: hooks lead (candidate openings), each root claim becomes a section
  # with its children nested beneath it, unparented support gathers under
  # Notes, references and open questions close the outline.
  class Linearizer
    attr_reader :idea

    def initialize(idea)
      @idea = idea
    end

    def to_markdown
      sections = [ frontmatter, "# #{idea.display_title}" ]
      sections << hooks_section
      sections << claims_section
      sections << notes_section
      sections << references_section
      sections << questions_section
      sections.compact.join("\n\n") + "\n"
    end

    private

    def nodes
      @nodes ||= idea.idea_nodes.ordered.to_a
    end

    def of_type(type)
      nodes.select { |n| n.node_type == type.to_s && n.parent_id.nil? }
    end

    def children_of(node)
      nodes.select { |n| n.parent_id == node.id }
    end

    def frontmatter
      thesis = nodes.find(&:thesis?)
      lines = [ "---", "title: #{idea.display_title.inspect}" ]
      lines << "audience: #{idea.audience.inspect}" if idea.audience.present?
      lines << "thesis: #{thesis.body.inspect}" if thesis
      lines << "seeded: #{idea.created_at.to_date.iso8601}"
      lines << "outlined: #{Date.current.iso8601}"
      lines << "status: outline"
      lines << "---"
      lines.join("\n")
    end

    def hooks_section
      hooks = of_type(:hook)
      return nil if hooks.empty?

      "**Possible openings:**\n\n" + hooks.map { |h| "> #{h.body}" }.join("\n>\n")
    end

    # Thesis first: the spine of the post leads the outline.
    def claims_section
      thesis_claims, rest = of_type(:claim).partition(&:thesis?)
      claims = thesis_claims + rest
      return nil if claims.empty?

      claims.map { |claim| claim_block(claim) }.join("\n\n")
    end

    def claim_block(claim)
      lines = [ "## #{claim.body}" ]
      bullets = bullet_tree(children_of(claim))
      lines << bullets if bullets.present?
      lines.join("\n\n")
    end

    # Loose supporting material that never got attached under a claim.
    def notes_section
      loose = nodes.select do |n|
        n.parent_id.nil? && %w[example counterpoint].include?(n.node_type)
      end
      return nil if loose.empty?

      "## Notes\n\n" + bullet_tree(loose)
    end

    # Reference nodes from the interview plus links the writer dropped in —
    # both belong in the drafting handoff.
    def references_section
      lines = of_type(:reference).map { |r| "- #{r.body}" }
      lines += idea.scraps.link.ordered.map do |scrap|
        "- [#{scrap.display_title}](#{scrap.url})"
      end
      return nil if lines.empty?

      "## References\n\n" + lines.join("\n")
    end

    def questions_section
      open = nodes.select { |n| n.node_type == "question" && n.open? }
      return nil if open.empty?

      "## Open questions\n\n" + open.map { |q| "- #{q.body}" }.join("\n")
    end

    def bullet_tree(list, depth = 0)
      list.map do |node|
        label = node.node_type == "example" ? "" : "*#{node.node_type}:* "
        line = "#{'  ' * depth}- #{label}#{node.body}"
        kids = bullet_tree(children_of(node), depth + 1)
        kids.present? ? "#{line}\n#{kids}" : line
      end.join("\n")
    end
  end
end
