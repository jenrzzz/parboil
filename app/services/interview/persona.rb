module Interview
  # The interviewer's prompt material — local for now, shaped like a hob
  # persona (system core + rendering helpers) so it can migrate into hob's
  # persona system when that ships. See DESIGN.md: the persona stays local
  # until hob owns personas.
  module Persona
    SYSTEM_CORE = <<~PROMPT.freeze
      You are an interviewer helping a writer develop a blog post idea. Your
      only job is to ask the single most useful next question.

      Hard rules — these are the product, not suggestions:
      - Ask EXACTLY ONE question per turn. No preamble, no summary, no praise.
        Output the question and nothing else.
      - Never write prose for the post. Never suggest sentences, phrasings,
        titles, or wording. Never put words in the writer's mouth.
      - Be pointed and specific. Ground every question in something the writer
        actually said; quote their own phrase back when it sharpens the ask.
      - Push where the idea is thinnest: an unsupported claim wants an example,
        a one-sided take wants the strongest counterargument, an abstract point
        wants a concrete story, a finished-seeming idea wants its opening hook.
      - One thing at a time. A question with "and also" in it is two questions.
    PROMPT

    module_function

    # Render the full prompt for the next-question call: persona + idea state
    # + transcript, ending with the ask. Single string because the interviewer
    # is a service call on the transcript, not a resumed chat session.
    def next_question_prompt(idea)
      <<~PROMPT
        #{SYSTEM_CORE}
        The writer's seed for this post:
        #{idea.seed.strip}

        #{material_digest(idea)}#{graph_digest(idea)}#{ripeness_gaps(idea)}
        Interview so far:
        #{transcript_digest(idea)}

        Ask the single most useful next question.
      PROMPT
    end

    def opening_prompt(idea)
      <<~PROMPT
        #{SYSTEM_CORE}
        The writer's seed for this post:
        #{idea.seed.strip}

        #{material_digest(idea)}
        This is the very first question of the interview. Ask the one question
        that best helps the writer start talking — aimed at the heart of what
        they seem to want to say, not at logistics.
      PROMPT
    end

    # The writer pressed "I'm stuck" on the pending question. Same shape as
    # next_question_prompt but the ask inverts: instead of the most useful
    # question, the *smallest* one that still faces the same gap. Ripeness
    # gaps are deliberately omitted — steering someone stuck toward checklist
    # coverage is exactly the wrong moment; stay on this hole.
    def stepping_stone_prompt(idea, depth: 1)
      <<~PROMPT
        #{SYSTEM_CORE}
        The writer's seed for this post:
        #{idea.seed.strip}

        #{material_digest(idea)}#{graph_digest(idea)}
        Interview so far:
        #{transcript_digest(idea)}

        The writer is STUCK on your last question — it asked for more than
        they can produce right now. Do not answer it for them, and do not
        change the subject. Ask a smaller question that is a first step
        toward the same gap. Smaller means one of: narrower scope; one
        concrete moment, memory, or example instead of a general point;
        their gut reaction instead of a worked-out position; or a choice
        between two readings of something they already said.
        #{escalation_note(depth)}
      PROMPT
    end

    # Depth 1 is the first stuck press; deeper means the stepping stones
    # themselves aren't landing, so shrink harder and finally make the block
    # itself the subject — naming why a question is hard is also an answer.
    def escalation_note(depth)
      return "" if depth <= 1

      <<~NOTE.strip
        This is stepping-stone attempt #{depth} — the previous smaller
        questions did not unstick them. Go much smaller: ask something
        answerable in a single sentence, or ask what makes this hard to
        talk about. Naming the block is also an answer.
      NOTE
    end

    # Budget per scrap and for the whole material section, so a long article
    # can't crowd out the transcript.
    SCRAP_CHAR_BUDGET = 1_500
    MATERIAL_CHAR_BUDGET = 6_000

    # Raw material the writer dropped in. Context for sharper questions —
    # explicitly NOT the writer's own words, and the prompt says so, because
    # the dogmatic rule extends here: their post is built from what THEY say,
    # not from what they've read.
    def material_digest(idea)
      scraps = idea.scraps.ordered
      return "" if scraps.empty?

      remaining = MATERIAL_CHAR_BUDGET
      entries = []
      scraps.each do |scrap|
        break if remaining <= 0

        header = scrap.link? ? "#{scrap.display_title} (#{scrap.url})" : "pasted note: #{scrap.display_title}"
        excerpt = scrap.body.to_s.truncate([ SCRAP_CHAR_BUDGET, remaining ].min)
        remaining -= excerpt.length
        entries << (excerpt.present? ? "--- #{header}\n#{excerpt}" : "--- #{header}\n(not fetched — link only)")
      end

      <<~SECTION
        Material the writer dropped in for reference. This is OTHER PEOPLE'S
        writing or the writer's collected notes — never attribute it to the
        writer or treat it as their position. Use it to ask sharper questions:
        where do they agree, disagree, or go further than this material?

        #{entries.join("\n\n")}

      SECTION
    end

    # What the checklist still lacks, so the interview converges on
    # draft-ready instead of wandering. Framed as steering, not a script — a
    # sharp follow-up on what was just said still wins.
    def ripeness_gaps(idea)
      return "" if idea.ripe?

      missing = idea.ripeness.missing
      return "" if missing.empty?

      gaps = missing.map { |c| c.detail ? "#{c.label} (#{c.detail})" : c.label }
      <<~SECTION
        For this post to be draft-ready it still needs: #{gaps.join('; ')}.
        Steer toward these gaps when it feels natural — but a sharp follow-up
        on what the writer just said beats a checklist question.

      SECTION
    end

    # What the graph already holds, so the interviewer pushes on gaps instead
    # of re-covering ground.
    def graph_digest(idea)
      nodes = idea.idea_nodes.ordered
      return "The idea graph is empty so far.\n" if nodes.empty?

      lines = nodes.map { |n| "- [#{n.node_type}#{n.open? ? ', open' : ''}] #{n.body}" }
      "Points already captured in the idea graph:\n#{lines.join("\n")}\n"
    end

    def transcript_digest(idea, turns: 12)
      idea.transcript.last(turns).map do |node|
        speaker = node.interviewer? ? "Interviewer" : "Writer"
        "#{speaker}: #{node.content}"
      end.join("\n\n")
    end
  end
end
