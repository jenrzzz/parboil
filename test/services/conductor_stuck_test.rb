require "test_helper"

# The stuck flow: step_down! never skips the pending question — it chains a
# smaller question underneath it, and depth grows with consecutive presses.
class ConductorStuckTest < ActiveSupport::TestCase
  setup do
    @idea = Idea.create!(seed: "an itch", status: :interviewing)
    @conductor = Interview::Conductor.new(@idea)
    question = MessageNode.create!(idea: @idea, role: :interviewer, content: "the big question?")
    @idea.update!(head_hash: question.content_hash)
    @question = question
  end

  test "step_down! chains stepping stones under the stuck question" do
    first = stub_llm_complete("one concrete time?") { @conductor.step_down! }
    assert_equal @question.content_hash, first.parent_hash
    assert_equal first, @idea.head
    assert_equal 2, @conductor.stuck_depth

    second = stub_llm_complete("gut reaction, one sentence?") { @conductor.step_down! }
    assert_equal first.content_hash, second.parent_hash
    assert_equal 3, @conductor.stuck_depth
  end

  test "stuck_depth resets once the writer answers" do
    stub_llm_complete("smaller?") { @conductor.step_down! }
    answer = MessageNode.create!(idea: @idea, role: :user, content: "an answer", parent_hash: @idea.head_hash)
    @idea.update!(head_hash: answer.content_hash)

    assert_equal 0, @conductor.stuck_depth
  end

  test "stepping stone prompt stays on the gap and skips ripeness steering" do
    prompt = Interview::Persona.stepping_stone_prompt(@idea, depth: 1)
    assert_includes prompt, "STUCK"
    assert_includes prompt, "same gap"
    assert_not_includes prompt, "draft-ready" # no checklist steering while stuck
    assert_not_includes prompt, "Naming the block" # no escalation on first press
  end

  test "deep stuck escalates to naming the block" do
    prompt = Interview::Persona.stepping_stone_prompt(@idea, depth: 3)
    assert_includes prompt, "attempt 3"
    assert_includes prompt, "Naming the block is also an answer"
  end
end
