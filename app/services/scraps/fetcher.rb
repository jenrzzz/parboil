require "net/http"

module Scraps
  # Deterministic page fetch + text extraction for link scraps. No LLM: the
  # material goes into the interviewer's context as-is, budget-capped.
  #
  # Deliberately modest: tight timeouts, few redirects, HTML only, hard size
  # caps. A failed fetch is not an error condition for the caller — the scrap
  # keeps the bare URL and the interview goes on.
  class Fetcher
    OPEN_TIMEOUT  = 5   # seconds
    READ_TIMEOUT  = 8
    MAX_REDIRECTS = 3
    MAX_BYTES     = 1_000_000
    MAX_TEXT      = 15_000  # chars of extracted text kept on the scrap

    Result = Data.define(:title, :body, :error) do
      def ok? = error.nil?
    end

    def self.call(url)
      new.call(url)
    end

    def call(url, redirects_left = MAX_REDIRECTS)
      uri = URI.parse(url)
      return failure("only http(s) URLs") unless uri.is_a?(URI::HTTP)

      response = get(uri)

      case response
      when Net::HTTPRedirection
        return failure("too many redirects") if redirects_left.zero?
        location = URI.join(uri, response["location"]).to_s
        call(location, redirects_left - 1)
      when Net::HTTPSuccess
        unless response.content_type.to_s.include?("html") || response.content_type.to_s.start_with?("text/")
          return failure("not a text page (#{response.content_type})")
        end
        extract(response.body.to_s.byteslice(0, MAX_BYTES))
      else
        failure("HTTP #{response.code}")
      end
    rescue URI::InvalidURIError
      failure("invalid URL")
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout => e
      failure(e.class.name.demodulize)
    end

    private

    def get(uri)
      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == "https",
                      open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri, { "User-Agent" => "parboil/1.0 (personal idea tool)" }))
      end
    end

    def extract(html)
      doc = Nokogiri::HTML(html.scrub)
      doc.css("script, style, nav, header, footer, aside, form, iframe, noscript").each(&:remove)

      title = doc.at_css("title")&.text&.strip&.truncate(200)
      # Prefer the page's own idea of main content when it declares one.
      content = doc.at_css("article") || doc.at_css("main") || doc.at_css("body") || doc
      text = content.text.gsub(/[ \t]+/, " ").gsub(/\n\s*\n\s*/, "\n\n").strip.truncate(MAX_TEXT)

      return failure("no readable text") if text.blank?

      Result.new(title: title, body: text, error: nil)
    end

    def failure(message)
      Result.new(title: nil, body: nil, error: message)
    end
  end
end
