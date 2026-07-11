module Interview
  # Pulls typed IdeaNodes out of one interview answer. The extraction is the
  # byproduct mechanism from DESIGN.md: the writer just talks; the graph grows.
  # Bodies are the writer's own words (tight trimming allowed, no invention) —
  # the LLM classifies and extracts, it never writes content.
  class Extractor
    SCHEMA = {
      type: "object",
      properties: {
        nodes: {
          type: "array",
          items: {
            type: "object",
            properties: {
              node_type: {
                type: "string",
                enum: IdeaNode.node_types.keys,
                description: "claim: something the post asserts. example: concrete instance or story. " \
                             "question: an open thread the writer raised or left dangling. " \
                             "counterpoint: an objection or opposing view the writer voiced. " \
                             "reference: an external source, work, or prior art the writer mentioned. " \
                             "hook: a phrase or moment that could open the post."
              },
              body: {
                type: "string",
                description: "The point in the writer's own words, trimmed to stand alone. " \
                             "Never paraphrase into your words; never add content they didn't say."
              }
            },
            required: %w[node_type body],
            additionalProperties: false
          }
        },
        title: {
          type: %w[string null],
          description: "A working title ONLY if the writer themselves said a phrase that works as one; otherwise null. Their words, not yours."
        }
      },
      required: %w[nodes],
      additionalProperties: false
    }.freeze

    attr_reader :idea

    def initialize(idea)
      @idea = idea
    end

    # Extract from a persisted answer node. Returns the created IdeaNodes.
    def extract!(answer_node)
      result = LLM::Gateway.complete(
        role: :extractor,
        schema: SCHEMA,
        messages: prompt(answer_node),
        operation: "interview.extract",
        metadata: { idea_id: idea.id, answer_hash: answer_node.content_hash }
      )
      apply(result, answer_node)
    end

    private

    def prompt(answer_node)
      question = answer_node.parent&.content
      <<~PROMPT
        You extract structured notes from a blog-idea interview. Work ONLY from
        the writer's answer below — the question is context, not content. Every
        body must be the writer's own words, trimmed to stand alone. Extract
        the few points that matter; an answer usually yields 1-4 nodes, not a
        node per sentence. If the answer holds nothing extractable, return an
        empty nodes array.

        Interviewer's question (context only):
        #{question || '(none — this was an opening statement)'}

        Writer's answer (extract from this):
        #{answer_node.content}
      PROMPT
    end

    def apply(result, answer_node)
      data = result.is_a?(Hash) ? result.with_indifferent_access : {}
      position = idea.idea_nodes.maximum(:position).to_i

      created = Array(data[:nodes]).filter_map do |node|
        node_type = node[:node_type].to_s
        body = node[:body].to_s.strip
        next unless IdeaNode.node_types.key?(node_type) && body.present?

        idea.idea_nodes.create!(
          node_type: node_type,
          body: body,
          status: node_type == "question" ? :open : :settled,
          position: (position += 1),
          source_message: answer_node
        )
      end

      if idea.title.blank? && data[:title].present?
        idea.update!(title: data[:title].to_s.strip.truncate(120))
      end

      created
    end
  end
end
