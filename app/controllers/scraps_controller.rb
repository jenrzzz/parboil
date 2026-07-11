class ScrapsController < ApplicationController
  # One form, two shapes: a URL makes a link scrap (fetched synchronously,
  # failure tolerated — the bare link is still context), pasted text makes a
  # paste scrap. URL wins when both are given; the paste can follow separately.
  def create
    idea = Idea.find(params[:idea_id])
    url = params.dig(:scrap, :url).to_s.strip
    body = params.dig(:scrap, :body).to_s.strip

    if url.present?
      create_link(idea, url)
    elsif body.present?
      idea.scraps.create!(kind: :paste, body: body, title: params.dig(:scrap, :title).presence)
      redirect_to idea_path(idea), notice: "Scrap added."
    else
      redirect_to idea_path(idea), alert: "Paste something or give a URL."
    end
  end

  def destroy
    scrap = Scrap.find(params[:id])
    idea = scrap.idea
    scrap.destroy!
    redirect_to idea_path(idea), notice: "Scrap removed."
  end

  private

  def create_link(idea, url)
    scrap = idea.scraps.new(kind: :link, url: url)
    unless scrap.valid?
      return redirect_to idea_path(idea), alert: scrap.errors.full_messages.to_sentence
    end

    result = Scraps::Fetcher.call(url)
    if result.ok?
      scrap.assign_attributes(title: result.title, body: result.body)
      scrap.save!
      redirect_to idea_path(idea), notice: "Fetched “#{scrap.display_title}”."
    else
      scrap.save!
      redirect_to idea_path(idea),
                  notice: "Couldn't read the page (#{result.error}) — kept the link itself as context."
    end
  end
end
