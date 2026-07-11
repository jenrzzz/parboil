# parboil's local LLM gateway config.
#
# This is the hob-shaped seam (see DESIGN.md). Surfaces never ask for a model
# ID — they ask for a *role* (`interviewer`, `extractor`), and this config maps
# the role to a concrete provider+model. When hob's real gateway ships, that
# mapping moves into hob and this file shrinks to a client-library handoff.
module LLM
  class Configuration
    # Role → concrete model. The only place model IDs live. hob calls these
    # "model roles"; the swap is: delete this table, point roles at hob.
    ROLE_MODELS = {
      # The questioner. Quality of the question is the whole product, so it
      # gets the strong model.
      interviewer: "claude-sonnet-4-6",
      # Cheap structured extraction of typed nodes from an answer. Classifier
      # work — Haiku is plenty.
      extractor:   "claude-haiku-4-5"
    }.freeze

    attr_accessor :api_key, :pricing
    attr_reader :role_models

    def initialize
      @api_key     = Rails.application.credentials.dig(:anthropic, :api_key) || ENV["ANTHROPIC_API_KEY"]
      @role_models = ROLE_MODELS.dup
      @pricing = {
        # USD per 1M tokens.
        "claude-haiku-4-5"  => { input: 1.00, output: 5.00 },
        "claude-sonnet-4-6" => { input: 3.00, output: 15.00 },
        "claude-opus-4-8"   => { input: 5.00, output: 25.00 }
      }
    end

    def model_for(role)
      role_models.fetch(role.to_sym) do
        raise LLM::Error, "unknown model role: #{role.inspect} (known: #{role_models.keys.join(', ')})"
      end
    end

    def cost_per_million(model, type)
      pricing.dig(model, type) || 0
    end

    def calculate_cost(model, input_tokens, output_tokens)
      input_cost  = (input_tokens  / 1_000_000.0) * cost_per_million(model, :input)
      output_cost = (output_tokens / 1_000_000.0) * cost_per_million(model, :output)
      (input_cost + output_cost).round(6)
    end
  end

  class Error < StandardError; end
  class RateLimitError < Error; end
  class ApiError < Error; end

  # RubyLLM raises its own HTTP-mapped error classes. Callers that drive RubyLLM
  # directly (rather than through LLM::Client) can wrap in this to get the same
  # LLM::RateLimitError / LLM::ApiError classification for uniform job retries.
  TRANSIENT_RUBYLLM_ERRORS = [
    RubyLLM::RateLimitError,
    RubyLLM::OverloadedError,
    RubyLLM::ServiceUnavailableError,
    RubyLLM::ServerError
  ].freeze

  def self.normalize_errors
    yield
  rescue *TRANSIENT_RUBYLLM_ERRORS => e
    raise RateLimitError, "#{e.class.name.demodulize}: #{e.message}"
  rescue RubyLLM::Error => e
    raise ApiError, "#{e.class.name.demodulize}: #{e.message}"
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield config
  end

  def self.enabled?
    config.api_key.present?
  end
end

if LLM.enabled?
  RubyLLM.configure do |config|
    config.anthropic_api_key = LLM.config.api_key
    config.use_new_acts_as = true # We don't use acts_as; this silences its deprecation warning.
  end

  # Workaround for ruby_llm/Anthropic SSE streaming buffering (lifted from kat).
  #
  # Cloudflare gzips Anthropic's SSE with infrequent deflate flushes; Ruby's
  # Net::HTTP auto-inflates and can't yield decompressed bytes until each flush,
  # batching token chunks into late bursts. Sending Accept-Encoding: identity on
  # streaming requests bypasses the inflater. Mirrors ruby_llm PR #771 — drop
  # once that merges and ruby_llm is bumped.
  Rails.application.config.to_prepare do
    RubyLLM::Providers::Anthropic::Streaming.module_eval do
      private

      def stream_response(connection, payload, additional_headers = {}, &block)
        super(connection, payload, additional_headers.merge("Accept-Encoding" => "identity"), &block)
      end
    end
  end
end
