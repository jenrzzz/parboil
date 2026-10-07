module ApplicationHelper
  def safe_external_url(scrap)
    scrap.http_url
  end
end
