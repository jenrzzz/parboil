class IdeasController < ApplicationController
  before_action :set_idea, only: [ :show, :answer, :next_question, :outline ]

  # LLM failures surface as a flash, never a 500 — the writer's words are
  # already persisted by the time any model call runs.
  rescue_from LLM::Error do |e|
    redirect_to @idea ? idea_path(@idea) : root_path,
                alert: "The interviewer is unavailable right now (#{e.message.truncate(120)}). Nothing you wrote was lost."
  end

  def index
    @ideas = Idea.order(updated_at: :desc)
    @idea = Idea.new
  end

  # Seed capture must be instant: no LLM call here. The interview starts
  # explicitly from the idea page.
  def create
    idea = Idea.new(idea_params)
    if idea.save
      redirect_to idea_path(idea)
    else
      redirect_to root_path, alert: idea.errors.full_messages.to_sentence
    end
  end

  def show
    @conductor = Interview::Conductor.new(@idea)
    @transcript = @idea.transcript
    @nodes_by_type = @idea.idea_nodes.ordered.group_by(&:node_type)
  end

  # One full turn. The answer is saved before extraction or the next question,
  # so a mid-turn failure loses nothing (show page then offers resume).
  def answer
    text = params.require(:answer).to_s.strip
    if text.blank?
      return redirect_to idea_path(@idea), alert: "Say something first."
    end

    Interview::Conductor.new(@idea).advance!(text)
    redirect_to idea_path(@idea)
  end

  # Start the interview (seeded idea) or regenerate the pending question
  # (a turn that died between answer and question).
  def next_question
    conductor = Interview::Conductor.new(@idea)
    if @idea.head_hash.blank?
      conductor.start!
    elsif conductor.awaiting_question?
      conductor.ask_next!
    end
    redirect_to idea_path(@idea)
  end

  def outline
    render plain: Outline::Linearizer.new(@idea).to_markdown,
           content_type: "text/markdown; charset=utf-8"
  end

  private

  def set_idea
    @idea = Idea.find(params[:id])
  end

  def idea_params
    params.require(:idea).permit(:seed)
  end
end
