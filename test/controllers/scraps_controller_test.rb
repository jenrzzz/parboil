require "test_helper"

class ScrapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @idea = Idea.create!(seed: "test seed about friction")
  end

  # minitest 6 no longer ships minitest/mock; this is all we need from it.
  def with_fetcher_result(result)
    original = Scraps::Fetcher.method(:call)
    Scraps::Fetcher.define_singleton_method(:call) { |_url| result }
    yield
  ensure
    Scraps::Fetcher.define_singleton_method(:call, original)
  end

  test "creates a paste scrap" do
    assert_difference -> { @idea.scraps.paste.count } do
      post idea_scraps_path(@idea), params: { scrap: { body: "a pasted note" } }
    end
    assert_redirected_to idea_path(@idea)
    assert_equal "a pasted note", @idea.scraps.last.body
  end

  test "creates a link scrap with fetched title and body" do
    result = Scraps::Fetcher::Result.new(title: "A Page", body: "page text", error: nil)
    with_fetcher_result(result) do
      post idea_scraps_path(@idea), params: { scrap: { url: "https://example.com/a" } }
    end
    scrap = @idea.scraps.link.last
    assert_equal "A Page", scrap.title
    assert_equal "page text", scrap.body
    assert_not scrap.unfetched?
  end

  test "keeps the bare link when the fetch fails" do
    result = Scraps::Fetcher::Result.new(title: nil, body: nil, error: "ReadTimeout")
    with_fetcher_result(result) do
      post idea_scraps_path(@idea), params: { scrap: { url: "https://example.com/slow" } }
    end
    scrap = @idea.scraps.link.last
    assert scrap.unfetched?
    assert_equal "example.com", scrap.host
  end

  test "rejects a non-http url" do
    assert_no_difference -> { Scrap.count } do
      post idea_scraps_path(@idea), params: { scrap: { url: "ftp://bad.example" } }
    end
    assert_match(/must be http/, flash[:alert])
  end

  test "rejects an empty submission" do
    assert_no_difference -> { Scrap.count } do
      post idea_scraps_path(@idea), params: { scrap: { url: "", body: "  " } }
    end
    assert_match(/Paste something/, flash[:alert])
  end

  test "destroys a scrap" do
    scrap = @idea.scraps.create!(kind: :paste, body: "bye")
    assert_difference -> { Scrap.count }, -1 do
      delete scrap_path(scrap)
    end
    assert_redirected_to idea_path(@idea)
  end
end
