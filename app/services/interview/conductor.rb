module Interview
  # Drives one idea's interview: first question from the seed, then
  # answer → extract → next question, appending immutable nodes to the DAG
  # and moving the idea's head pointer.
  #
  # Failure posture: the writer's answer is persisted before any LLM call, and
  # extraction failure never blocks the next question (the ledger records it;
  # extraction can rerun later). If question generation itself fails, the head
  # is left on the answer node and ask_next! resumes from there.
  class Conductor
    class AlreadyStarted < StandardError; end
    class NotStarted < StandardError; end

    attr_reader :idea

    def initialize(idea)
      @idea = idea
    end

    # Open the interview: the first question, from the seed alone.
    def start!
      raise AlreadyStarted if idea.head_hash.present?

      question = LLM::Gateway.complete(
        role: :interviewer,
        messages: Persona.opening_prompt(idea),
        operation: "interview.open",
        metadata: { idea_id: idea.id }
      )
      node = append!(role: :interviewer, content: question.strip, parent_hash: nil)
      idea.update!(head_hash: node.content_hash, status: :interviewing)
      node
    end

    # One full turn: record the answer, grow the graph, ask the next question.
    # Returns the new interviewer node.
    def advance!(answer_text)
      raise NotStarted if idea.head_hash.blank?

      answer = append!(role: :user, content: answer_text.to_s.strip, parent_hash: idea.head_hash)
      idea.update!(head_hash: answer.content_hash)

      begin
        Extractor.new(idea).extract!(answer)
      rescue LLM::Error => e
        Rails.logger.error("parboil extraction failed (idea=#{idea.id}, answer=#{answer.content_hash}): #{e.message}")
      end

      ask_next!
    end

    # Generate the next question from the current head. Public so a turn that
    # died between answer and question can resume. Idempotent when a question
    # is already pending (double-submit, stray caller): asking the model for a
    # question right after its own unanswered question only confuses it.
    def ask_next!
      raise NotStarted if idea.head_hash.blank?
      return idea.head if idea.head&.interviewer?

      question = LLM::Gateway.complete(
        role: :interviewer,
        messages: Persona.next_question_prompt(idea),
        operation: "interview.question",
        metadata: { idea_id: idea.id }
      )
      node = append!(role: :interviewer, content: question.strip, parent_hash: idea.head_hash)
      idea.update!(head_hash: node.content_hash)
      node
    end

    # The pending question, if the interview is waiting on the writer.
    def pending_question
      head = idea.head
      head if head&.interviewer?
    end

    # True when the last turn is an unanswered writer message (question
    # generation failed mid-turn) — the show page offers a resume.
    def awaiting_question?
      idea.head&.user? || false
    end

    private

    # Append honoring content-addressing: identical (role, content, parent)
    # is the same node — reuse instead of colliding on the primary key.
    def append!(role:, content:, parent_hash:)
      raise ArgumentError, "empty message" if content.blank?

      hash = MessageNode.compute_hash(
        role: role.to_s, speaker_name: nil, content: content, parent_hash: parent_hash
      )
      MessageNode.find_by(content_hash: hash) ||
        MessageNode.create!(idea: idea, role: role, content: content, parent_hash: parent_hash)
    end
  end
end
